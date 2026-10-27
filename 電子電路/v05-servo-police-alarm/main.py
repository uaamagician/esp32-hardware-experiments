from machine import Pin, PWM, ADC
import time

led_pwm = PWM(Pin(2), freq=5000)
buzzer = PWM(Pin(17), freq=1000)
buzzer.duty(0)
red = Pin(5, Pin.OUT)
blue = Pin(16, Pin.OUT)
red.value(0)
blue.value(0)
servo = PWM(Pin(22), freq=50)

pot = ADC(Pin(4))
pot.atten(ADC.ATTN_11DB)
ldr = ADC(Pin(34))
ldr.atten(ADC.ATTN_11DB)

delay_ms = 15
DARK_LEVEL = 3000
ALARM_SEC = 5
HOME = 90
PRINT_MS = 500

sweep = 0
step = 40

pattern = [(1,0),(0,0),(1,0),(0,0),(0,1),(0,0),(0,1),(0,0)]
p_idx = 0
last_flash = time.ticks_ms()
last_print = time.ticks_ms()

servo_angle = HOME
servo_dir = 4
last_duty = -10

running = False
armed = True
alarm_start = 0

last_move = time.ticks_ms()
released = False

def read_avg(adc, n=8):
    total = 0
    for _ in range(n):
        total += adc.read_u16()
    return total // n

def set_angle(a):
    global last_duty, last_move, released
    a = max(10, min(170, a))
    d = int(31 + a / 180 * 92)
    if abs(d - last_duty) >= 2:
        servo.duty(d)
        last_duty = d
        last_move = time.ticks_ms()
        released = False

def quiet():
    buzzer.duty(0)
    red.value(0)
    blue.value(0)
    set_angle(HOME)

set_angle(HOME)

while True:
    try:
        raw = read_avg(pot)
        val = read_avg(ldr) >> 4
        duty = raw >> 6
        led_pwm.duty(duty)

        is_dark = val >= DARK_LEVEL
        alarm_cond = duty > 700 or is_dark
        now = time.ticks_ms()

        if alarm_cond:
            if armed:
                armed = False
                running = True
                alarm_start = now
                servo_angle = HOME
        else:
            armed = True
            running = False

        if running and time.ticks_diff(now, alarm_start) >= ALARM_SEC * 1000:
            running = False

        if running:
            base = 200 + raw // 65
            sweep += step
            if sweep > 400 or sweep < 0:
                step = -step
            buzzer.freq(base + sweep)
            buzzer.duty(300)

            if time.ticks_diff(now, last_flash) >= 60:
                last_flash = now
                r, b = pattern[p_idx]
                red.value(r)
                blue.value(b)
                p_idx = (p_idx + 1) % len(pattern)

            servo_angle += servo_dir
            if servo_angle >= 135 or servo_angle <= 45:
                servo_dir = -servo_dir
            set_angle(servo_angle)

        elif alarm_cond or duty < 30:
            sweep = 0
            p_idx = 0
            quiet()

        else:
            sweep = 0
            p_idx = 0
            red.value(0)
            blue.value(0)
            buzzer.freq(200 + raw // 65)
            buzzer.duty(300)
            set_angle(raw * 180 // 65535)

        if not released and time.ticks_diff(now, last_move) > 600:
            servo.duty(0)
            released = True

        if time.ticks_diff(now, last_print) >= PRINT_MS:
            last_print = now
            print("pot:", raw, " ldr:", val, " dark:", is_dark, " running:", running)

        time.sleep_ms(delay_ms)

    except KeyboardInterrupt:
        buzzer.duty(0)
        led_pwm.duty(0)
        red.value(0)
        blue.value(0)
        set_angle(HOME)
        time.sleep_ms(500)
        servo.deinit()
        print("已停止")
        break
    except Exception as e:
        print("錯誤:", e)
        time.sleep_ms(200)
