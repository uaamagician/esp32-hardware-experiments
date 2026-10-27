from ble_uart import BLE_UART
from servo import Servo
from machine import Pin
from time import sleep_ms

my_servo = Servo(22)
ble = BLE_UART("door_lock")
button = Pin(23, Pin.IN, Pin.PULL_UP)

OPEN_ANGLE = 10
CLOSE_ANGLE = 90
is_open = False

def move(angle):
    my_servo.rotate(angle)
    sleep_ms(500)
    my_servo.servo.duty(0)

def open_door(source):
    global is_open
    move(OPEN_ANGLE)
    is_open = True
    print("開啟（來源：" + source + "）")
    ble.send("opened by " + source)

def close_door(source):
    global is_open
    move(CLOSE_ANGLE)
    is_open = False
    print("關閉（來源：" + source + "）")
    ble.send("closed by " + source)

close_door("start")

while True:
    getValue = ble.get().lower()
    if getValue == "open":
        open_door("phone")
    elif getValue == "close":
        close_door("phone")

    if button.value() == 0:
        sleep_ms(30)
        if button.value() == 0:
            ble.send("button pressed")
            print("按鈕被按下")
            if is_open:
                close_door("button")
            else:
                open_door("button")
            while button.value() == 0:
                sleep_ms(10)

    sleep_ms(20)
