# SwasthAI — System Architecture

```mermaid
graph TD
    subgraph Hardware ["Edge Sensing Unit (ESP32)"]
        Sensors["MAX30102 (SpO2 & HR)<br>Pressure Sensor (Breathing)<br>Microphone (Cough)"]
        Firmware["Arduino C++ Firmware<br>(BLE GATT Server)"]
        Sensors --> Firmware
    end

    subgraph Client ["Frontline Companion App (Flutter)"]
        BLE["BLE Central Service"]
        UI["Flutter UI<br>(Live Waveforms & Forms)"]
        LocalDB["Flutter SQLite Storage"]
        Engine["Local Risk Assessment Engine"]
        
        Firmware -.->|BLE Notifications| BLE
        BLE --> UI
        UI --> LocalDB
        UI --> Engine
    end

    subgraph Backend ["Edge / Companion Backend (FastAPI)"]
        API["FastAPI REST Endpoints<br>(/api/patients, /api/screenings)"]
        Services["Service Layer<br>(Orchestration & Validation)"]
        Repos["Repository Layer<br>(Clean Data Access)"]
        SQLAlchemy["SQLAlchemy 2.0 ORM"]
        SQLite[("Local SQLite Database<br>WAL Mode + FK Enabled")]

        UI -.->|HTTP JSON (Offline Network)| API
        API --> Services
        Services --> Repos
        Repos --> SQLAlchemy
        SQLAlchemy --> SQLite
    end
```

---

## Technical Specifications
- **BLE Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **BLE Characteristic UUID**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- **FastAPI Port**: `8000` (Localhost / Wi-Fi Hotspot)
- **Database**: SQLite 3 with Write-Ahead Logging (`PRAGMA journal_mode=WAL`)
