from ble_uart import BLE_UART
from servo import Servo

my_servo = Servo(22)
ble = BLE_UART("door_lock")

my_servo.rotate(90)

while True:
    getValue = ble.get()
    getValue = getValue.lower()

    if getValue == "open":
        my_servo.rotate(0)
        print("開啟")
        ble.send("opened")

    if getValue == "close":
        my_servo.rotate(90)
        print("關閉")
        ble.send("closed")
