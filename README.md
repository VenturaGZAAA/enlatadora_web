# Arquitectura de Integración e Interacción del Sistema: Enlatadora Industrial

Este documento describe la arquitectura distribuida, los protocolos de comunicación, los flujos de datos y la interacción en tiempo real entre los dos subsistemas que integran la enlatadora automatizada: **Enlatadora_IoT** (Maestro / HMI / Gateway) y **Enlatadora_Control** (Esclavo / Controlador de Tiempo Real y Seguridad).

---

## 1. Visión General de la Arquitectura Distribuida

El sistema implementa un modelo desacoplado Maestro-Esclavo ejecutado sobre dos microcontroladores **ESP32-S3** independientes, dividiendo claramente las tareas de tiempo real crítico y seguridad física de las tareas de conectividad, procesamiento de voz en la nube e interfaces de usuario.

```
+===================================================================================================+
|                                        INTERFACES EXTERNAS                                        |
|   +--------------------+     +---------------------+     +------------------+     +-----------+   |
|   | Dashboard Web (SD) |     | Clientes MQTT / App |     | Micrófono I2S    |     | Consola   |   |
|   | (HTTP :80 / WS)    |     | (TCP 1883 / WS 8080)|     | (Groq Whisper IA)|     | Serial    |   |
+===+---------+----------+=====+----------+----------+=====+--------+---------+=====+-----+-----+===+
              |                           |                         |                     |
              +---------------------------+------------+------------+---------------------+
                                                       |
                                                       v
+===================================================================================================+
|                     NODO MAESTRO / GATEWAY (Proyecto: Enlatadora_IoT)                             |
|                                                                                                   |
|  - WifiManager (STA/AP, mDNS: enlatadora-master.local)                                            |
|  - MqttManager (Broker PicoMQTT embebido TCP 1883 + WebSockets 8080)                              |
|  - WebSeverManager (Servidor de archivos estáticos desde SD y endpoints OTA/REST)                 |
|  - VoiceKeywordModule (Captura DMA, empaquetado WAV, API Groq Whisper, matching de comandos)     |
|  - MachineMaster (Coordinador de comandos, telemetría y seguridad de nivel superior)              |
|  - EvenTheRGBLedHasManagers (Señalización LED RGB en GPIO 48)                                     |
+================================================+==================================================+
                                                 |
                                                 | Bus Serie Bidireccional
                                                 | UART @ 115200 bps
                                                 | (IoT TX:18 -> Ctrl RX:44 | Ctrl TX:43 -> IoT RX:17)
                                                 v
+================================================+==================================================+
|               NODO ESCLAVO / CONTROL INDUSTRIAL (Proyecto: Enlatadora_Control)                    |
|                                                                                                   |
|  - UARTManager (Instancia master, colas thread-safe FreeRTOS a 50 Hz)                             |
|  - CanningMachine (FSM determinista de 26 etapas: Reposo -> Llenado -> Tapado -> Sellado)        |
|  - CanningMachineAutoUpdate (Muestreo continuo de entradas I0..I7 cada 10 ms)                     |
|  - pausableDelay (Retardo seguro con snapshot y restauración de salidas)                          |
|  - WifiManager (STA, mDNS: enlatadora-control.local) & WebSeverManager (OTA de rescate)           |
|  - EvenTheRGBLedHasManagers (Señalización de estado local en GPIO 48)                             |
+================================================+==================================================+
                                                 |
                                                 v
+===================================================================================================+
|                                    HARDWARE FÍSICO DE PLANTA                                      |
|                                                                                                   |
|   [ 8 Entradas Digitales / Sensores I0..I7 ]     |     [ 19 Salidas Digitales / Actuadores Q0..Q18 ] |
|   - Verificación de lata (I0)                    |     - Cintas y cadenas transportadoras            |
|   - Posicionamiento en salida y entrada (I1..I3) |     - Válvula de llenado y dosificación tolva     |
|   - Pulsadores autorización y parada (I4, I5)    |     - Pistón dispensador, ventosa y vacío de tapas|
|   - Fin de carrera ventosa / tapas (I7)          |     - Mordaza de pallet y motor de sellado        |
+===================================================================================================+
```

### 1.1 Resumen de Roles y Responsabilidades

| Dimensión | Enlatadora_IoT (Maestro) | Enlatadora_Control (Esclavo) |
|---|---|---|
| **Rol Principal** | Gateway IoT, HMI, Broker MQTT, IA por Voz. | Controlador determinista de planta (PLC embebido). |
| **Tiempo Real** | Blando / Asíncrono (Red, HTTP, JSON, Audio). | Estricto / Determinista (FSM, muestreo E/S cada 10 ms). |
| **Control Físico** | Sin E/S industriales directas (solo UART, SD, I2S, RGB). | 8 Entradas digitales (`I0`..`I7`) y 19 Salidas (`Q0`..`Q18`). |
| **Gestión de Red** | Broker MQTT (TCP/WS), Servidor Web Dashboard, mDNS (`enlatadora-master`). | Servidor Web ligero para OTA (`enlatadora-control`). |
| **Seguridad** | Validación previa de permisos y bloqueo de comandos conflictivos. | Enclavamientos de hardware, `pausableDelay`, parada de emergencia. |

---

## 2. Interfaz Física y Capa de Enlace (UART)

La interconexión principal entre ambos microcontroladores es un enlace serial punto a punto full-duplex de alta fiabilidad.

### 2.1 Mapeo de Pines y Conexión

```
   +-----------------------+                    +-----------------------+
   |     ESP32-S3 IoT      |                    |   ESP32-S3 Control    |
   |                       |                    |                       |
   |  GPIO 18 (TX / Serial1)+------------------->+ GPIO 44 (RX / Serial) |
   |  GPIO 17 (RX / Serial1)<-------------------+ GPIO 43 (TX / Serial) |
   |  GND                  +--------------------+ GND                   |
   +-----------------------+                    +-----------------------+
```

- **Velocidad de Transferencia:** 115200 baudios (8N1).
- **Abstracción:** Ambos proyectos emplean `UARTManager`, que encapsula colas FIFO (`std::queue<std::string>`) protegidas por mutexes FreeRTOS con un límite de 100 mensajes para evitar saturación de memoria RAM.
- **Frecuencia de Procesamiento:** Tarea `SerialQueue` en Core 1 a 50 Hz (período de 20 ms).

---

## 3. Protocolos de Comunicación y Formato de Mensajes

El canal serial transporta dos tipos de información: telemetría continua de estado (Esclavo -> Maestro) e instrucciones de control (Maestro -> Esclavo).

```
                      TELEMETRÍA (JSON cada 50 ms)
   Enlatadora_Control -----------------------------> Enlatadora_IoT
                      <-----------------------------
                      COMANDOS (Texto / JSON Seguro)
```

### 3.1 Flujo Esclavo -> Maestro: Telemetría de Estado

Cada 50 ms, el bucle principal de `Enlatadora_Control` serializa el estado atómico del sistema mediante `CanningMachine::getSerializedState()` y lo transmite por UART.

#### Estructura del JSON Emitido por el Controlador:
```json
{
  "running": true,
  "emergencyStop": false,
  "paused": false,
  "authorizedSystem": true,
  "forcedAuthorization": false,
  "stage_name": "Llenado",
  "stage_num": 5,
  "inputs": {
    "I0": false,
    "I1": true,
    "I2": true,
    "I3": false,
    "I4": false,
    "I5": false,
    "I6": false,
    "I7": true
  },
  "outputs": {
    "Q0": false,
    "Q1": true,
    "Q2": false,
    "Q3": false,
    "Q4": false,
    "Q5": false,
    "Q6": false,
    "Q7": false,
    "Q8": false,
    "Q9": false,
    "Q10": false,
    "Q11": false,
    "Q12": false,
    "Q13": false,
    "Q14": false,
    "Q15": false,
    "Q16": false,
    "Q17": true,
    "Q18": false
  }
}
```

#### Procesamiento en `Enlatadora_IoT`:
1. `UARTManager` / `Monitor` detecta el salto de línea y deserializa el JSON con `ArduinoJson`.
2. `MachineMaster::processMachineState` actualiza las banderas internas:
    - `machineRunning = doc["running"]`
    - `emergencyStop = doc["emergencyStop"]`
    - `machinePaused = doc["paused"]`
    - `currentStageName = doc["stage_name"]`, `currentStageNumber = doc["stage_num"]`
    - Arreglos booleanos `inputState[8]` y `outputState[19]`.

---

### 3.2 Flujo Maestro -> Esclavo: Comandos Operativos y Control de Salidas

`Enlatadora_IoT` envía comandos hacia `Enlatadora_Control` en dos formatos según la naturaleza de la acción:

#### A. Comandos de Texto (Control de Ciclo y FSM)
Enviados como cadenas terminadas en `\n`:
- `Start`: Inicia la tarea `run()` de la FSM en el controlador.
- `Stop`: Detiene inmediatamente la FSM, apaga todas las salidas (`allOff()`) y retorna a `Stage::Reposo`.
- `Pause`: Activa `softwarePause = true`, disparando el mecanismo `pausableDelay` que guarda snapshot y apaga actuadores.
- `Resume`: Desactiva `softwarePause = false`, restaurando el estado de los actuadores y continuando el ciclo.
- `ForceAuthorization`: Fuerza `forcedAuthorization = true` para pruebas y bypass de sensores físicos `I4`/`I5`.

#### B. Comandos JSON (Control Directo de Salidas / Actuadores)
Enviados cuando un usuario comanda actuadores individuales desde el Dashboard Web o MQTT:
```json
{
  "Q0": true,
  "Q1": false
}
```

---

## 4. Flujos Operativos y Casos de Uso Integrados

### 4.1 Flujo 1: Inicio y Ejecución del Ciclo Automático de Enlatado

```
[Usuario / App] -> Publica en MQTT "machine/command" ("Start")
       |
       v
[Enlatadora_IoT::MqttManager] -> Invoca callback -> [MachineMaster::processCommands("Start")]
       |
       v
[Enlatadora_IoT::UARTManager] -> Envía texto "Start\n" por Serial1 (GPIO 18)
       |
       v  (UART Bus)
[Enlatadora_Control::UARTManager] -> Recibe en Serial (GPIO 44) -> Dispara [CanningMachine::processTextCommands]
       |
       v
[Enlatadora_Control::CanningMachine] -> Ejecuta start() -> Crea tarea FreeRTOS "CanningMachine" (Core 1, 8KB Stack)
       |
       +---> Inicia FSM en Stage::Reposo (0)
       |     Valida authorizedSystem (I4 presionado o forcedAuthorization)
       |
       +---> Avanza secuencialmente por las 26 etapas:
             [1] EsperaLata (Activa cinta Q16) -> Sensor I3 detecta lata
             [2-4] Tope activo y elevación de tolva (Q18, Q17)
             [5-6] Llenado con válvula Q1 y descenso
             [7-9] Traslado a salida (sensor I2) y arrastre por cadenas (Q0, Q11, Q12, Q15)
             [10-14] Dispensado y colocación neumática de tapa (Q4, Q3, Q5, succión Q6, sensor I7)
             [15-18] Transporte en banda 3 (Q14), tope (Q7), mordaza pallet (Q8) y elevación (Q9)
             [19-21] Verificación (sensor I0) y sellado rotativo de alta potencia (Q13)
             [22-25] Descenso (Q9), liberación (Q8), evacuación en banda 3 (sensor I1) y retorno a Reposo
```

Durante todo el ciclo, `Enlatadora_Control` reporta cada transición cada 50 ms por UART, y `Enlatadora_IoT` actualiza las telemetrías MQTT y el LED de estado.

---

### 4.2 Flujo 2: Telemetría Hacia la Nube y Dashboard Web

`Enlatadora_IoT` desacopla la alta frecuencia interna (50 ms) de la carga de red externa, publicando periódicamente según prioridades:

```
                  +----------------------------------------------+
                  |           Enlatadora_Control                 |
                  +----------------------+-----------------------+
                                         |
                                         | UART JSON (50 ms)
                                         v
                  +----------------------------------------------+
                  |             Enlatadora_IoT                   |
                  |             (MachineMaster)                  |
                  +----------------------+-----------------------+
                                         |
         +-------------------------------+-------------------------------+
         | (Cada 1000 ms)                | (Cada 200 ms)                 | (Cada 200 ms)
         v                               v                               v
[machine/state/read]           [machine/IO/outputs/read]        [machine/IO/inputs/read]
{                              {                                {
  "running": true,               "Q0": false, "Q1": true,         "I0": false, "I1": true,
  "paused": false,               "Q2": false, ...                 "I2": true, "I3": false,
  "stage_name": "Llenado",       "Q18": false                     ... "I7": true
  "stage_num": 5,              }                                }
  "emergencyStop": false
}
         |                               |                               |
         +-------------------------------+-------------------------------+
                                         |
                                         v
                  +----------------------------------------------+
                  |         Broker MQTT / WebSockets             |
                  |     (TCP:1883 / WS:8080 en ESP32-IoT)        |
                  +----------------------+-----------------------+
                                         |
                                         v
                  [ Dashboard Web / App Móvil / SCADA ]
```

---

### 4.3 Flujo 3: Control por Voz Mediante Inteligencia Artificial (Groq Whisper)

```
[Operador] ---> "¡Arranca la máquina!" (Audio al micrófono INMP441)
     |
     v
[Enlatadora_IoT::VoiceKeywordModule] (Core 1, I2S DMA, 16 kHz Mono)
     | - Detecta audio y calcula RMS (descarta silencio si RMS < 500)
     | - Pasa fragmento de audio a la cola 'audioQueue'
     v
[VoiceUpload Task] (Core 0)
     | - Encapsula en formato WAV estándar (44 bytes cabecera)
     | - Envía HTTP POST multipart a API de Groq (whisper-large-v3-turbo)
     v
[Groq API Cloud] ---> Retorna JSON: {"text": "arranca la maquina"}
     |
     v
[Enlatadora_IoT::VoiceKeywordModule]
     | - Analiza coincidencias con el diccionario de MachineMaster ("arranca" -> Commands::Start)
     | - Publica en MQTT "voice/keyword/match" -> "arranca"
     | - Publica en MQTT "voice/keyword/transcription" -> "arranca la maquina"
     v
[Enlatadora_IoT::MachineMaster] ---> Envía comando UART: "Start\n"
     |
     v
[Enlatadora_Control] ---> Inicia el ciclo automático de enlatado.
```

---

### 4.4 Flujo 4: Control Manual y Seguridad con Doble Enclavamiento

Cuando un operador desea accionar una salida manualmente (p. ej., activar la válvula de llenado `Q1` para limpieza o purga), el sistema aplica un estricto **doble filtro de validación**:

```
[Operador en Web/MQTT] ---> Solicita {"Q1": true} en 'machine/IO/outputs/write'
                                      |
                                      v
                 [ FILTRO 1: Enlatadora_IoT (MachineMaster) ]
                 1. ¿emergencyStop == true? -> SI: RECHAZA ORDEN.
                 2. ¿allowOutputOverride == false? -> SI: RECHAZA ORDEN.
                 3. ¿machineRunning && !machinePaused? -> SI: RECHAZA (evita colisión).
                 4. Si es seguro: Transmite JSON {"Q1": true} por UART.
                                      |
                                      v (UART)
                 [ FILTRO 2: Enlatadora_Control (CanningMachine) ]
                 1. ¿hardwarePause activo? -> SI: RECHAZA ORDEN.
                 2. ¿machineRunning && !softwarePause? -> SI: RECHAZA ORDEN.
                 3. Si es seguro: Ejecuta digitalWrite(ACTUATOR_PINS[1], HIGH).
```

---

### 4.5 Flujo 5: Gestión de Pausas y Paradas de Emergencia (`pausableDelay`)

El sistema garantiza que la interrupción del proceso no provoque pérdida de producto, desalineaciones ni daños en el utillaje mecánico:

```
[Evento de Pausa] (Pulsador físico I5, comando MQTT "Pause", o comando de voz "Pausa")
       |
       v
[Enlatadora_Control::CanningMachine] -> Establece softwarePause = true
       |
       v
[Dentro de pausableDelay(ms)]
       1. Captura snapshot de todas las salidas Q0..Q18 en memoria:
          snapshot[o] = outputState[o].load();
       2. Apaga instantáneamente todos los actuadores:
          allOff(); // Válvulas cerradas, motores detenidos, vacío apagado.
       3. Permanece en bucle de espera activa no bloqueante:
          while (isPaused()) { vTaskDelay(1); }
       4. Al recibir "Resume" / reanudación:
          Restaura con precisión las salidas: writeOutput(o, snapshot[o]);
          Continúa la temporización en el milisegundo exacto donde se detuvo.
```

---

## 5. Señalización Visual Sincronizada (LED RGB NeoPixel)

Ambos nodos cuentan con un LED WS2812 direccionable en el pin GPIO 48 gestionado por la librería compartida `EvenTheRGBLedHasManagers`. Los estados se coordinan visualmente:

| Evento / Estado | Enlatadora_IoT (GPIO 48) | Enlatadora_Control (GPIO 48) |
|---|---|---|
| **Arranque / Start** | Pulso Verde (1000 ms) | Pulso Verde (1000 ms) |
| **Parada / Stop** | Pulso Rojo (1000 ms) | Pulso Rojo (1000 ms) |
| **Pausa / Emergencia** | Pulso Magenta (1000 ms) | Pulso Magenta (1000 ms) |
| **Máquina en Ejecución Normal** | Fondo Verde / Dinámico | Fondo Blanco (50% brillo) |
| **Máquina en Pausa** | Fondo Magenta | Fondo Amarillo (50% brillo) |
| **Escucha Activa de Voz** | Fondo Azul (mientras graba/procesa) | - |
| **Falla de Conexión WiFi** | Rojo fijo | - |
| **Petición Web / OTA** | Destello Amarillo | Destello Verde al conectar |

---

## 6. Mantenimiento, Actualizaciones OTA y Scripts de Soporte

La infraestructura incluye mecanismos para mantener sincronizados y actualizados ambos dispositivos:

```
                                  [ Estación de Trabajo / PC ]
                                                |
                        +-----------------------+-----------------------+
                        |                                               |
                        v                                               v
               [ sync_machines.sh ]                            [ updateBoth.sh ]
               Sincroniza archivos compartidos:                Flashea vía OTA en orden:
               - UARTManager                                   1. Enlatadora_Control (/firmware)
               - WifiManager                                   2. Enlatadora_IoT (/firmware)
               - WebSeverManager
               - EvenTheRGBLedHasManagers
```

### 6.1 Identificación de Red mDNS y Puertos
- **Enlatadora_IoT:** `http://enlatadora-master.local`
    - Puerto 80: Servidor Web (Dashboard SD en `/CanningMachine/web`, OTA en `/firmware`, REST `/wifi/set`).
    - Puerto 1883: Broker MQTT TCP.
    - Puerto 8080: Broker MQTT WebSockets.
- **Enlatadora_Control:** `http://enlatadora-control.local`
    - Puerto 80: Servidor Web ligero exclusivamente para OTA `/firmware` y mantenimiento.

### 6.2 Seguridad en Actualizaciones OTA
Cuando se ejecuta `updateBoth.sh`, el script envía el nuevo binario a `Enlatadora_Control`. Al concluir la carga, el callback `onUpdateSuccessful` detiene de inmediato el proceso industrial (`CanningMachine::processCommand(Stop)`), asegura todas las salidas apagadas (`allOff()`) y aplica un retardo de 1 segundo antes de invocar `ESP.restart()`, previniendo movimientos no controlados durante el flasheo.

---

## 7. Matriz Resumen de Interacción entre Nodos

| Recurso / Función | Origen | Destino | Medio / Protocolo | Payload / Formato |
|---|---|---|---|---|
| **Telemetría General** | `Enlatadora_Control` | `Enlatadora_IoT` | UART (GPIO 43 -> 17) | JSON (cada 50 ms) con estados, etapa, E/S. |
| **Comando Start / Stop / Pause** | `Enlatadora_IoT` | `Enlatadora_Control` | UART (GPIO 18 -> 44) | Texto plano (`Start\n`, `Stop\n`, `Pause\n`, etc.). |
| **Comando Forzado de Salidas** | `Enlatadora_IoT` | `Enlatadora_Control` | UART (GPIO 18 -> 44) | JSON `{"Qx": bool}` con validación previa de seguridad. |
| **Telemetría a Clientes** | `Enlatadora_IoT` | Dashboard / MQTT | Wi-Fi / MQTT (1883/8080)| Tópicos `machine/state/read`, `machine/IO/*`. |
| **Comandos de Voz** | Micrófono I2S / Groq | `Enlatadora_IoT` -> Ctrl | I2S -> HTTP -> UART | Audio WAV -> JSON Groq -> Comando UART. |
| **Actualizaciones de Firmware**| Script PC | Ambos ESP32 | HTTP POST `/firmware` | Binario de firmware con parada segura previa. |
| **Sincronización de Drivers** | Código Fuente | Repositorio local | Script `sync_machines.sh`| Sincronización rsync de controladores universales. |

---

## 8. Conclusiones Arquitectónicas

La interacción entre **Enlatadora_IoT** y **Enlatadora_Control** proporciona una solución industrial robusta que maximiza el rendimiento y la seguridad operativa:

1. **Aislamiento de Fallos y Determinismo:** Las operaciones que requieren alta latencia o acceso a la nube (como la transcripción de audio en Groq o la atención de peticiones HTTP/WebSockets) residen en el ESP32 IoT, garantizando que el ciclo de control de la FSM en el ESP32 de Control nunca sufra retardos (jitter) ni bloqueos.
2. **Seguridad en Capas:** Ambos nodos validan de forma independiente las condiciones operativas antes de alterar actuadores físicos, asegurando que un fallo en la interfaz de usuario nunca ponga en riesgo la integridad mecánica de la enlatadora.
3. **Mantenibilidad y Escalabilidad:** El uso de controladores universales sincronizados y protocolos estandarizados (JSON sobre UART y MQTT sobre TCP/WebSockets) facilita la adición de nuevos sensores, etapas en la FSM o paneles de control sin necesidad de reestructurar el sistema completo.
