from ble_uart import BLE_UART
from servo import Servo
from machine import Pin, ADC
from time import sleep_ms, ticks_ms, ticks_diff

my_servo = Servo(22)
ble = BLE_UART("door_lock")
button = Pin(23, Pin.IN, Pin.PULL_UP)
pot = ADC(Pin(34))
pot.atten(ADC.ATTN_11DB)

CLOSE_ANGLE = 10
MIN_OPEN = 30
MAX_OPEN = 170

def read_open_angle():
    total = 0
    for _ in range(16):
        total += pot.read_u16()
    raw = total // 16
    return MIN_OPEN + raw * (MAX_OPEN - MIN_OPEN) // 65535

is_open = False
last_move = ticks_ms()
settled = True
last_shown = -1

def go(a):
    global last_move, settled
    my_servo.rotate(a)
    last_move = ticks_ms()
    settled = False

def open_door(source):
    global is_open
    a = read_open_angle()
    go(a)
    is_open = True
    print("開啟", a, "度（來源：" + source + "）")
    ble.send("opened " + str(a) + " by " + source)

def close_door(source):
    global is_open
    go(CLOSE_ANGLE)
    is_open = False
    print("關閉（來源：" + source + "）")
    ble.send("closed by " + source)

close_door("start")

while True:
    now = ticks_ms()

    a = read_open_angle()
    if abs(a - last_shown) >= 3:
        last_shown = a
        print("旋鈕選擇：", a, "度")

    cmd = ble.get().lower()
    if cmd == "open":
        open_door("phone")
    elif cmd == "close":
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

    if not settled and ticks_diff(now, last_move) > 500:
        my_servo.servo.duty(0)
        settled = True

    sleep_ms(20)
