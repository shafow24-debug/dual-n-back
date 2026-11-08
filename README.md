# 🧠 Dual N-Back para iOS (SwiftUI Nativo)

Aplicación nativa de entrenamiento científico de memoria de trabajo (**Dual N-Back**), basada en el protocolo experimental de **Jaeggi et al. (2008)** y las mecánicas de **Brain Workshop**. Diseñada en **Swift 5.9+ y SwiftUI** para **iOS 16.0+**, con motor de temporización monotónico sin deriva, generador determinista con control de señuelos (*lures* $N-1$ y $N+1$) y síntesis de voz de baja latencia en español.

---

## 📁 Estructura del Proyecto

```text
DualNBack/
├── project.yml
├── scripts/
│   └── generate_icon.swift
├── .github/
│   └── workflows/
│       └── build-ipa.yml
├── DualNBack/
│   ├── App/
│   │   └── DualNBackApp.swift
│   ├── Theme/
│   │   └── Theme.swift
│   ├── Models/
│   │   ├── GameSettings.swift
│   │   ├── SessionResult.swift
│   │   └── StimulusStep.swift
│   ├── Engine/
│   │   ├── SequenceGenerator.swift
│   │   └── GameEngine.swift
│   ├── Audio/
│   │   ├── SpeechManager.swift
│   │   └── HapticsManager.swift
│   ├── Storage/
│   │   └── StorageManager.swift
│   ├── Views/
│   │   ├── HomeView.swift
│   │   ├── GameView.swift
│   │   ├── PauseModalView.swift
│   │   ├── ResultsView.swift
│   │   ├── HistoryView.swift
│   │   ├── StatsView.swift
│   │   ├── SettingsView.swift
│   │   ├── InstructionsSheetView.swift
│   │   └── Components/
│   │       ├── NLevelSelector.swift
│   │       ├── CustomSlider.swift
│   │       └── BrainHeaderIllustration.swift
│   └── Assets.xcassets/
└── DualNBackTests/
    └── SequenceAndScoringTests.swift
```

---

## 🚀 Guía Paso a Paso desde Windows: Compilar el `.ipa` en GitHub Actions

No necesitas una Mac ni tener Xcode instalado. Todo el proceso de generación del ícono (`1024x1024`), creación del proyecto `.xcodeproj` con **XcodeGen**, ejecución de pruebas unitarias y empaquetado del archivo `DualNBack.ipa` sin firmar se ejecuta en la nube con **GitHub Actions**.

### Paso 1: Crear un repositorio en GitHub y subir el código desde Windows

1. Entra en [github.com/new](https://github.com/new) e inicia sesión.
2. Ponle un nombre al repositorio (por ejemplo, `dual-n-back-ios`), elígelo **Público** (en repositorios públicos los minutos de macOS en GitHub Actions son gratuitos) y haz clic en **Create repository** (sin marcar *Add a README*).
3. Abre **PowerShell** en tu PC con Windows y ejecuta estos comandos dentro de la carpeta `DualNBack`:

```powershell
cd "C:\Users\a24le\OneDrive\Documentos\Antigravity\DualNBack"

git init
git branch -M main
git add .
git commit -m "Initial commit: Dual N-Back iOS App completa"
git remote add origin https://github.com/TU_USUARIO/dual-n-back-ios.git
git push -u origin main
```
*(Sustituye `TU_USUARIO` por tu nombre de usuario real de GitHub).*

---

### Paso 2: Ejecutar el Workflow y descargar `DualNBack.ipa`

1. En tu repositorio de GitHub, haz clic en la pestaña superior **Actions**.
2. Verás ejecutándose automáticamente el flujo **"Build Unsigned iOS IPA (Dual N-Back)"** tras el `git push`.
   - También puedes lanzarlo manualmente cuando quieras entrando en **Build Unsigned iOS IPA (Dual N-Back)** a la izquierda y pulsando el botón **Run workflow**.
3. Espera entre **2 y 3 minutos** hasta que aparezca el ícono verde ✅.
4. Entra en la ejecución completada y desplázate hasta la sección inferior **Artifacts**.
5. Haz clic en **`DualNBack-Unsigned-IPA`** para descargar el archivo `.zip` a tu PC.
6. Descomprímelo en Windows: dentro encontrarás el archivo **`DualNBack.ipa`** listo para instalar.

---

## 📲 Cómo Firmar e Instalar el `.ipa` en tu iPhone desde Windows

### Opción A: Usando Sideloadly (Recomendado por rapidez)

1. Asegúrate de tener instalados en Windows **iTunes** e **iCloud** (las versiones de descarga directa de Apple, no las de la Microsoft Store).
2. Descarga e instala [Sideloadly](https://sideloadly.io/) para Windows.
3. Conecta tu iPhone a tu PC mediante cable USB y selecciona **"Confiar en esta computadora"** en la pantalla del iPhone.
4. Abre **Sideloadly**:
   - Verifica que tu iPhone aparezca detectado en el campo **iDevice**.
   - Escribe tu correo de **Apple ID** en el campo **Apple Account**.
   - Arrastra el archivo **`DualNBack.ipa`** al recuadro de **IPA** de Sideloadly.
   - Haz clic en el botón **Start** (si es tu primera vez, te pedirá la contraseña de tu Apple ID y el código de 6 dígitos de verificación para solicitar el certificado gratuito de desarrollo de Apple).
5. Cuando Sideloadly indique **`Done!`**, el ícono azul de **Dual N-Back** aparecerá en la pantalla de inicio de tu iPhone.

### Opción B: Usando AltStore

1. Con **AltServer** ejecutándose en la bandeja del sistema de Windows y tu iPhone conectado (por USB o misma red Wi-Fi):
2. Envía el archivo `DualNBack.ipa` a tu iPhone (por ejemplo, por iCloud Drive, Telegram o correo y guárdalo en la app **Archivos** del iPhone).
3. Abre **AltStore** en tu iPhone, ve a la pestaña **My Apps**, toca el botón **`+`** arriba a la izquierda y selecciona **`DualNBack.ipa`**.

---

## 🔐 Activar Permisos en iOS 16 / iOS 17 / iOS 18+ (Primera vez)

Cuando instalas una aplicación firmada con tu cuenta personal (Sideloading), iOS requiere dos pasos de seguridad la primera vez:

1. **Confiar en tu certificado de desarrollador**:
   - En tu iPhone, abre **Configuración > General > Administración de dispositivos y VPN**.
   - Debajo de *App de desarrollador*, toca tu correo de Apple ID.
   - Pulsa **"Confiar en [tu correo]"** y confirma en **"Confiar"**.
2. **Activar el Modo Desarrollador (obligatorio en iOS 16 o superior)**:
   - Ve a **Configuración > Privacidad y seguridad**.
   - Baja hasta el final y entra en **Modo desarrollador**.
   - Activa el interruptor, pulsa **Reiniciar** y, tras encender el iPhone, confirma en **Activar** e introduce el código de desbloqueo de tu pantalla.

---

## 🗣️ Consejo para la Mejor Voz en Español en tu iPhone

La aplicación detecta automáticamente las voces en español instaladas en tu iPhone priorizando calidad **Premium > Mejorada > Estándar** y región **`es-MX` > `es-US` > `es-ES`**. Para que las letras (`hache, jota, ka, ele, cu, erre, equis, te`) suenen con calidad humana de estudio:

1. En tu iPhone, ve a **Configuración > Accesibilidad > Contenido leído > Voces > Español**.
2. Elige tu variante preferida (ej. *Español (México)* o *Español (España)*) y descarga una voz con etiqueta **Mejorada** o **Premium** (como *Paulina (Mejorada)* o *Mónica (Premium)*).
3. Dentro de **Dual N-Back**, entra en **⚙️ Ajustes > Voz (Audio en Español)** y pulsa **"Probar voz"** para seleccionarla y escucharla.
