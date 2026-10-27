from servo import Servo
from ble_uart import BLE_UART
import time

servo = Servo(22)
ble = BLE_UART("ESP32-Servo")

HOME = 90
MIN_ANGLE = 10
MAX_ANGLE = 170

angle = HOME
servo.rotate(angle)

def move(a):
    global angle
    angle = max(MIN_ANGLE, min(MAX_ANGLE, a))
    servo.rotate(angle)
    ble.send("angle:" + str(angle))
    print("角度:", angle)

print("開始，手機傳 0~180、L、M、R、+、-")

while True:
    msg = ble.get()
    if msg:
        cmd = msg.lower()
        if cmd == "l":
            move(MIN_ANGLE)
        elif cmd == "m":
            move(HOME)
        elif cmd == "r":
            move(MAX_ANGLE)
        elif cmd == "+":
            move(angle + 10)
        elif cmd == "-":
            move(angle - 10)
        else:
            try:
                move(int(cmd))
            except ValueError:
                ble.send("?")
                print("看不懂:", msg)
    time.sleep_ms(20)
