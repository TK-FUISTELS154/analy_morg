# 🛡️ APEX SUITE PRO - Arquitectura, Módulos y Referencia Técnica

> **Framework Integral de Auditoría Heurística, Ingeniería Inversa, Telemetría y Dumper para Roblox (Niveles 3 a 8)**

---

## 📌 1. Visión General y Arquitectura

**APEX Suite** es una plataforma modular basada en Programación Orientada a Objetos (POO), desacoplamiento estricto por eventos (`EventBus`), inyección de dependencias (`Registry`), blindaje contra ofuscación de servicios (`ServiceResolver`) e inspección en memoria protegida (`CapabilityManager`).

```
suite/
├── init.lua                        # Bootstrapper universal (Local Filesystem + GitHub Raw HttpGet)
├── README.md                       # Documentación técnica completa y mapa del sistema
├── code/
│   ├── core/                       # Núcleo base, gestión de APIs y resolución universal
│   │   ├── Class.lua               # Motor de herencia y metatablas POO
│   │   ├── CapabilityManager.lua   # Detección de APIs del ejecutor y descompilación protegida
│   │   ├── EventBus.lua            # Bus pub/sub reactivo para comunicación entre módulos
│   │   ├── Logger.lua              # Sistema de bitácora y formateo de eventos con timestamps
│   │   ├── Registry.lua            # Service Locator / Contenedor de Inyección de Dependencias
│   │   └── ServiceResolver.lua     # Blindaje anti-ofuscación con 4 niveles de fallback por ClassName
│   ├── security/                   # Blindaje de ejecución y seguridad activa
│   │   ├── SecurityCore.lua        # Anti-Kick, Anti-AFK, Anti-OCR y aislamiento de ScreenGui
│   │   ├── HookManager.lua         # Gestión centralizada de metamethod hooks (__namecall, __index)
│   │   ├── MemoryGuard.lua         # Detección de fugas de memoria y limpieza de conexiones
│   │   └── SafeSandbox.lua         # Entorno sandbox protegido (pcall wrappers y timeouts)
│   ├── analysis/                   # Motores de análisis estático, dinámico y heurístico
│   │   ├── StructuralProfiler.lua  # Perfilado estructural de scripts y jerarquías
│   │   ├── HeuristicEngine.lua     # Motor heurístico multihilo de detección de vulnerabilidades
│   │   ├── RemoteAnalyzer.lua      # Análisis y clasificación de riesgo de RemoteEvents / RemoteFunctions
│   │   ├── ActionRecorder.lua      # Grabador de telemetría de acciones 2D/3D del jugador
│   │   ├── EconomyAuditor.lua      # Detección de fallos en transacciones, tiendas y divisas
│   │   └── PhysicsAuditor.lua      # Auditoría de físicas, colisiones, watchdogs y spoofing
│   ├── dumper/                     # Volcado, serialización y exportación
│   │   ├── VirtualTree.lua         # Estructura de datos virtualizada para árboles masivos
│   │   ├── SelectiveDumper.lua     # Volcado selectivo concurrente con filtro y podado
│   │   └── ReportExporter.lua      # Exportación estructurada a JSON, Markdown y TXT
│   └── integrations/               # Conectores con herramientas externas
│       └── ExternalTools.lua       # Integración con Selective Dumper, DarkDex, RemoteSpy y SimpleSpy
└── gui/                            # Interfaz Gráfica de Usuario (UI/UX Profesional)
    ├── MainWindow.lua              # Ventana principal, navegación por pestañas, drag, resize y modal DarkDex
    └── views/                      # Vistas especializadas
        ├── AuditView.lua           # Panel de auditoría heurística y ejecución de análisis
        ├── DumperView.lua          # Visor de jerarquía con Virtual Scroll, Inspector y Menú DarkDex
        ├── RemoteSpyView.lua       # Monitor de tráfico de red, logueo de remotos y filtros
        ├── ToolsView.lua           # Lanzador de herramientas externas
        └── SettingsView.lua        # Configuración de rendimiento, latencia y seguridad
```

---

## 📂 2. Referencia Detallada de Módulos y Funciones

### 🚀 `suite/init.lua` (Bootstrapper Principal)
- **Propósito**: Punto de entrada universal. Soporta ejecución local desde disco (`readfile`) y remota mediante `game:HttpGet` a GitHub.
- **Funciones clave**:
  - `ApexImport(relPath)`: Carga módulos dinámicamente con caché interna para evitar duplicación.
  - Inicializa `EventBus`, `Logger`, `Registry`, `ServiceResolver`, `CapabilityManager` y `SecurityCore`.
  - Instancia `MainWindow` y presenta la interfaz gráfica.

---

### 🧩 `code/core/` (Núcleo y Servicios Base)

#### 1. `Class.lua`
- Generador de clases POO en Lua con soporte para constructores `new()`, herencia y `isA()`.

#### 2. `CapabilityManager.lua`
- **Detección de Executor**: Detecta nivel de privilegios y APIs disponibles (`decompile`, `cloneref`, `hookmetamethod`, `getgenv`, `gethui`, `rconsolename`, etc.).
- **Descompilación Segura**: `SafeDecompile(scriptInstance)` implementa un Shared Memory Store con caché hash SHA-256 para no descompilar dos veces el mismo script.

#### 3. `EventBus.lua`
- **Patrón Pub/Sub**: Métodos `Subscribe(eventName, callback)`, `Unsubscribe(id)`, y `Publish(eventName, ...)`. Permite que `RemoteAnalyzer` notifique a `ActionRecorder` o a las vistas sin acoplamiento.

#### 4. `Logger.lua`
- **Registro Centralizado**: Métodos `Info()`, `Warn()`, `Error()`, `Debug()` con niveles de severidad y salida redirigible a la GUI y consola.

#### 5. `Registry.lua`
- **Service Locator**: `Register(name, instance)`, `Get(name)`, `Remove(name)` y `Destroy()`. Administra el ciclo de vida de los servicios singleton de la suite.

#### 6. `ServiceResolver.lua` ⚡ *(Nuevo Blindaje Anti-Ofuscación)*
- **Resolución Universal**: Inmune a juegos que renombran servicios (`Workspace`, `Players`, `ReplicatedStorage`) a GUIDs aleatorios.
- **Métodos**:
  - `GetService(className)`: Intenta `GetService`, `FindFirstChildOfClass`, `FindFirstChildWhichIsA` y barrido directo de hijos.
  - `GetPlayers()` / `GetLocalPlayer()`: Obtiene la instancia del jugador local de forma segura.
  - `GetPlayerGui()`: Obtiene el contenedor GUI del jugador.
  - `GetWorkspace()`: Fallback seguro a `workspace` global.

---

### 🔒 `code/security/` (Seguridad Activa)

#### 1. `SecurityCore.lua`
- **Anti-Kick**: Intercepta `LocalPlayer:Kick` con bypass inteligente para llamadas originadas por la suite.
- **Anti-AFK**: Vincula `VirtualUser` con `LocalPlayer.Idled` para prevenir desconexión por inactividad.
- **Anti-OCR**: Genera nombres pseudo-aleatorios únicos para las interfaces (`ScreenGui`) protegiéndolas de escaneos automáticos.
- **Contenedor Seguro**: `GetSecureGuiParent()` selecciona automáticamente `gethui()`, `cloneref(CoreGui)` o `PlayerGui`.

#### 2. `HookManager.lua`
- Administra hooks seguros sobre metamétodos (`__namecall`, `__index`, `__newindex`) preservando punteros originales para restauración limpia.

#### 3. `MemoryGuard.lua`
- Supervisa el consumo de memoria en tiempo real, detecta referencias circulares y limpia conexiones RBXScriptConnection obsoletas.

#### 4. `SafeSandbox.lua`
- Ejecuta fragmentos de código y callbacks de usuario con protección `pcall` y límites de tiempo para evitar congelamientos del hilo principal.

---

### 🧠 `code/analysis/` (Motores Heurísticos y de Auditoría)

#### 1. `StructuralProfiler.lua`
- Analiza la arquitectura del juego, profundidad de árboles de instancias, conteo de scripts clientes/módulos y distribución en memoria.

#### 2. `HeuristicEngine.lua`
- **Worker Pool Multihilo**: Analiza código fuente de scripts en lotes paralelos (`task.wait` amortiguado) buscando:
  - Backdoors y ejecución dinámica (`loadstring`, `getfenv`).
  - Vulnerabilidades en llamadas remotas.
  - Lógica de Anti-Cheats (Watchdogs, detección de WalkSpeed, CFrame, JumpPower).
  - Herramientas de Administrador ocultas.

#### 3. `RemoteAnalyzer.lua`
- Intercepta tráfico de red, registra argumentos y asigna un puntaje de riesgo (`Critical`, `High`, `Medium`, `Low`, `Safe`) a cada `RemoteEvent` y `RemoteFunction`.

#### 4. `ActionRecorder.lua`
- **Telemetría Unificada**: Graba en una línea de tiempo continua las entradas físicas del jugador (teclas, clics 2D, raycasts 3D) sincronizadas con los remotos disparados y snapshots físicos de 24 parámetros.

#### 5. `EconomyAuditor.lua`
- Escanea módulos y remotos relacionados con transacciones monetarias, monedas virtuales, tiendas y compras en busca de validación deficiente del lado del cliente.

#### 6. `PhysicsAuditor.lua`
- Captura snapshots de 24 parámetros físicos (masa de ensamble, colisiones anatómicas, distancia al suelo, velocidad de red, etc.) y detecta watchdogs de física locales.

---

### 📦 `code/dumper/` (Motor de Volcado y Exportación)

#### 1. `VirtualTree.lua`
- Estructura de árbol de alto rendimiento para representar millones de nodos sin sobrecargar el recolector de basura de Lua.

#### 2. `SelectiveDumper.lua`
- **Modos de Volcado**:
  1. *Subárbol Seleccionado*: Vuelca únicamente la rama especificada por el usuario.
  2. *Tipo de Instancia*: Vuelca todos los scripts o remotos.
  3. *Hallazgos Heurísticos*: Vuelca scripts clasificados como sospechosos por `HeuristicEngine`.
  4. *Entorno Completo*: Extracción concurrente y multihilo con podado automático de instancias core.

#### 3. `ReportExporter.lua`
- Serializa auditorías y volcados en formatos limpios:
  - **JSON**: Estructurado para análisis computacional automatizado.
  - **Markdown (MD)**: Tablas legibles, bloques de código, métricas y badges.
  - **Virtual File System (VFS)**: Exportación a carpetas locales usando `writefile` / `makefolder`.

---

### 🛠️ `code/integrations/` (Integraciones Externas)

#### `ExternalTools.lua`
- Permite lanzar herramientas auxiliares desde la GUI de la Suite:
  - **Selective Game Dumper**: Herramienta standalone con árbol virtual y menú DarkDex.
  - **DarkDex V3 / V4**: Explorador clásico de instancias.
  - **SimpleSpy / RemoteSpy**: Espías de red independientes.

---

### 🖥️ `gui/` (Interfaz de Usuario)

#### 1. `MainWindow.lua`
- **Splash Screen Loader**: Animación de carga moderna estilo DarkDex.
- **Top Bar & Tab Navigation**: Pestañas con transiciones suaves (`Audit`, `Dumper`, `RemoteSpy`, `Tools`, `Settings`).
- **Píldora Central de Minimización**: Al minimizar, se transforma en una píldora discreta en la parte superior central de la pantalla.
- **Resize Handle**: Esquina inferior derecha interactiva para redimensionar la ventana dinámicamente.

#### 2. `views/DumperView.lua`
- **Virtual Scrolling**: Renderizado reactivo capaz de mostrar miles de instancias a 60 FPS.
- **Inspector Inteligente**: Inspecciona propiedades 2D (GUI) y 3D (BaseParts, CFrames, Materiales) al instante.
- **Picker 2D / 3D**: Permite hacer clic sobre la pantalla para seleccionar automáticamente el elemento o modelo en el árbol.
- **Menú Contextual DarkDex**: Clic derecho sobre nodos para:
  - Copiar Ruta (`GetFullName()`).
  - Copiar Código / Script Source.
  - Renombrar Instancia.
  - Clonar / Eliminar.
  - Guardar Rama a JSON/MD.

#### 3. `views/AuditView.lua`
- Visualizador de hallazgos del motor heurístico con filtros por severidad (`Critical`, `High`, `Medium`, `Low`, `Info`).

#### 4. `views/RemoteSpyView.lua`
- Registro cronológico de remotos con visor de argumentos serializados, llamadas concurrentes y botón de copia rápida de script de disparo.

---

## 🚀 3. Instrucciones de Ejecución

### Carga Directa desde GitHub (Recomendada)
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/TK-FUISTELS154/analy_morg/main/suite/init.lua"))()
```

### Carga Local en Workspace del Executor
```lua
loadstring(readfile("suite/init.lua"))()
```

---

## 🛡️ 4. Compatibilidad y Soporte de Ejecutores

| API Requerida | Estado de Soporte | Fallback Aplicado |
| :--- | :---: | :--- |
| `gethui()` | ✅ Nativo | `CoreGui` con `cloneref` o `PlayerGui` |
| `cloneref()` | ✅ Nativo | Retorna referencia original |
| `hookmetamethod()` | ✅ Nativo | Modo pasivo de auditoría |
| `decompile()` | ✅ Nativo | Lectura protegida de Bytecode / Shared Cache |
| `writefile()` / `readfile()` | ✅ Nativo | Notificación en consola / Exportación en Portapapeles |
| `queue_on_teleport()` | ✅ Nativo | Re-ejecución automática en Server Hop |
| Servidores Ofuscados (GUIDs) | ✅ Nativo | Resolución por `ClassName` vía `ServiceResolver` |

---
*Desarrollado y optimizado para la suite de investigación de seguridad y reverse engineering.*
