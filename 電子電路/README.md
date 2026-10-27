# 電子電路實驗（ESP32 + MicroPython）

每個版本一個資料夾，裡面的 `main.py` 開頭都有：**硬體、腳位、功能、測試狀態**。
找東西時先看下面的總表。

- 開發板：ESP32 DevKit（30 腳，Generic ESP32 module）
- 韌體：MicroPython v1.29.0（`ESP32_GENERIC`）
- 編輯器：Thonny；終端機可用 `mpremote`

## 一、版本索引

| 版本 | 資料夾 | 做了什麼 | 用到的硬體 | 測試狀態 |
|---|---|---|---|---|
| v01 | [v01-pot-led-buzzer](v01-pot-led-buzzer/main.py) | 旋鈕調 LED 亮度，蜂鳴器音量跟著變 | LED、可變電阻、蜂鳴器 | 未實測 |
| v02 | [v02-police-lights-original-pins](v02-police-lights-original-pins/main.py) | 警車模式：警笛掃頻 + 紅藍閃燈（原本腳位） | + 紅燈、藍燈 | 未實測 |
| v03 | [v03-police-lights-right-side](v03-police-lights-right-side/main.py) | 同 v02，所有腳位改到板子右邊 | 同上 | 已跑，無錯誤 |
| v04 | [v04-ldr-night-mode](v04-ldr-night-mode/main.py) | 加光敏電阻，變暗自動警報 | + 光敏電阻、10kΩ | 已跑，光敏電路沒接好 |
| v05 | [v05-servo-police-alarm](v05-servo-police-alarm/main.py) | 加伺服馬達擺動，警報幾秒後結束並回原位 | + 伺服馬達 | 已跑，輸入沒接好未觸發 |
| v06 | [v06-servo-only](v06-servo-only/main.py) | 只剩伺服馬達：擺動後回原位，BOOT 鍵重來 | 伺服馬達 | 已跑，無錯誤 |
| v07 | [v07-ble-servo-commands](v07-ble-servo-commands/main.py) | 手機藍牙傳角度／L M R／+ - 控制馬達 | 伺服馬達、手機 | 未實測 |
| v08 | [v08-door-lock-ble](v08-door-lock-ble/main.py) | 門鎖遙控器（課本 AB03）：open / close | 伺服馬達、手機 | 藍牙啟動成功，馬達沒接 |
| v09 | [v09-door-lock-button](v09-door-lock-button/main.py) | 加實體按鈕，按下也回傳到手機 | + 4 腳按鈕 | 未實測 |
| v10 | [v10-door-lock-pot-select](v10-door-lock-pot-select/main.py) | 旋鈕先選開門角度，按下去才動 | + 可變電阻 | 未實測 |
| v11 | [v11-door-lock-ble-feedback](v11-door-lock-ble-feedback/main.py) | **最新版**：旋鈕角度、按鈕、狀態全回傳手機 | 同 v10 | 未實測 |

函式庫在 [libraries](libraries/)：`servo.py`、`ble_uart.py`（必須存到板子上，檔名不能改）。

## 二、用到的硬體清單

| 硬體 | 出現在 | 備註 |
|---|---|---|
| ESP32 DevKit | 全部 | |
| LED（亮度） | v01~v05 | PWM 5kHz |
| 紅燈、藍燈 LED + 220Ω | v02~v05 | 長腳接 GPIO，短腳經 220Ω 接 GND |
| 可變電阻 | v01~v05、v10、v11 | 兩側腳接 3V3 與 GND，中間腳接 ADC |
| 光敏電阻 + 10kΩ | v04、v05 | 要做分壓，不能只接一邊 |
| 蜂鳴器 | v01~v05 | 無源蜂鳴器才能改音調 |
| 伺服馬達（SG90 類） | v05~v11 | 紅=5V、棕/黑=GND、橘/黃=訊號 |
| 4 腳按鈕 | v09~v11 | 接對角兩隻腳 |
| 手機 | v07~v11 | Android: Serial Bluetooth Terminal（選 BLE）；iPhone: Bluefruit Connect |

## 三、腳位對照表（依版本）

| 零件 | v01 | v02 | v03 | v04 | v05 | v06 | v07~v08 | v09 | v10~v11 |
|---|---|---|---|---|---|---|---|---|---|
| 亮度 LED | 2 | 2 | 2 | 2 | 2 | | | | |
| 紅燈 | | 4 | 5 | 5 | 5 | | | | |
| 藍燈 | | 16 | 16 | 16 | 16 | | | | |
| 蜂鳴器 | 25 | 25 | 17 | 17 | 17 | | | | |
| 可變電阻 | 34 | 34 | 4 | 4 | 4 | | | | 34 |
| 光敏電阻 | | | | 34 | 34 | | | | |
| 伺服馬達訊號 | | | | | 22 | 22 | 22 | 22 | 22 |
| 按鈕 | | | | | | 0（BOOT 板載） | | 23 | 23 |
| 藍牙狀態 LED（函式庫內建） | | | | | | | 5 | 5 | 5 |

### 腳位使用規則

- 不要用 **GPIO0、GPIO15、TX0、RX0**（開機／燒錄會用到）。
- **GPIO6～11** 是 flash 專用，接了板子會無法開機。
- **GPIO34、35、36、39** 只能輸入，適合讀類比，不能輸出。
- **ADC2（GPIO4、2、15、13、12、14、25、26、27）** 在開 Wi-Fi 時讀不到；本實驗沒開 Wi-Fi，所以可用。
- 伺服馬達電源接 **VIN（5V）**；可變電阻電源接 **3V3**，**不能接 5V**。

## 四、遇到過的問題與解法

| 症狀 | 原因 | 解法 |
|---|---|---|
| 程式一跑就印「測試結束」 | Thonny 連線時會送中斷（Ctrl+C） | Tools → Options → Interpreter，取消 Interrupt working program on connect |
| Thonny 畫面愈來愈卡 | `print` 每 15ms 一次 | 改成每 0.5 秒印一次（v05 以後） |
| 終端機連不上板子 | Thonny 占住序列埠 | 先關掉 Thonny（⌘Q） |
| `could not enter raw repl`、一直重開機、`invalid header` | 板子 flash 沒回應（接線造成） | 拔掉所有杜邦線、換 USB 線；必要時用 esptool 重刷韌體 |
| 類比讀值一直是 0 或亂跳 | 可變電阻／光敏電阻沒接好 | 可變電阻中間腳接 ADC；光敏電阻要接分壓電路 |
| 伺服馬達一直嗡嗡響、轉不到底 | 0 度／180 度頂到機械極限 | 角度限制在 10~170；到位後 `servo.duty(0)` 放開 |
| `ble_uart.py` 報遞迴錯誤 | 有人在函式庫裡又建立 `BLE_UART(...)` | 藍牙名字要寫在主程式，不要改函式庫 |
| 課本程式 `Servo(Pin(22))` / `write_angle()` 報錯 | 本站函式庫介面不同 | 改成 `Servo(22)` / `rotate()` |

## 五、重刷 MicroPython 韌體

```bash
pip install esptool mpremote
esptool --chip esp32 --port /dev/cu.usbserial-0001 erase-flash
esptool --chip esp32 --port /dev/cu.usbserial-0001 --baud 460800 write-flash -z 0x1000 ESP32_GENERIC-20260824-v1.29.0.bin
```

韌體下載：<https://micropython.org/download/ESP32_GENERIC/>

## 六、上傳檔案到板子（終端機）

```bash
mpremote connect /dev/cu.usbserial-0001 fs cp libraries/servo.py :servo.py
mpremote connect /dev/cu.usbserial-0001 fs cp libraries/ble_uart.py :ble_uart.py
mpremote connect /dev/cu.usbserial-0001 run v11-door-lock-ble-feedback/main.py
```
