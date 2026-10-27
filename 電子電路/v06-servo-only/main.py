from machine import Pin, PWM
import time

servo = PWM(Pin(22), freq=50)
button = Pin(0, Pin.IN, Pin.PULL_UP)

HOME = 90
LOW = 45
HIGH = 135
RUN_SEC = 5
STEP = 3
DELAY_MS = 20

def set_angle(a):
    a = max(10, min(170, a))
    servo.duty(int(31 + a / 180 * 92))

def swing():
    angle = HOME
    direction = STEP
    start = time.ticks_ms()
    while time.ticks_diff(time.ticks_ms(), start) < RUN_SEC * 1000:
        angle += direction
        if angle >= HIGH or angle <= LOW:
            direction = -direction
        set_angle(angle)
        time.sleep_ms(DELAY_MS)
    set_angle(HOME)
    time.sleep_ms(600)
    servo.duty(0)

print("start")
swing()
print("done，按 BOOT 鍵再來一次")

while True:
    if button.value() == 0:
        print("start")
        swing()
        print("done")
        while button.value() == 0:
            time.sleep_ms(20)
    time.sleep_ms(50)
