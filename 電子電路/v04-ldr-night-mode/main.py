from machine import Pin, PWM, ADC
import time

led_pwm = PWM(Pin(2), freq=5000)
buzzer = PWM(Pin(17), freq=1000)
buzzer.duty(0)
red = Pin(5, Pin.OUT)
blue = Pin(16, Pin.OUT)
red.value(0)
blue.value(0)

pot = ADC(Pin(4))
pot.atten(ADC.ATTN_11DB)
ldr = ADC(Pin(34))
ldr.atten(ADC.ATTN_11DB)

delay_ms = 15
DARK_LEVEL = 3000
sweep = 0
step = 40

pattern = [(1,0),(0,0),(1,0),(0,0),(0,1),(0,0),(0,1),(0,0)]
p_idx = 0
last_flash = time.ticks_ms()

while True:
    raw = pot.read_u16()
    val = ldr.read_u16() >> 4
    duty = raw >> 6
    led_pwm.duty(duty)

    is_dark = val >= DARK_LEVEL
    alarm = duty > 700 or is_dark

    now = time.ticks_ms()

    if duty < 30 and not is_dark:
        buzzer.duty(0)
        red.value(0)
        blue.value(0)
    else:
        base = 200 + raw // 65

        if alarm:
            sweep += step
            if sweep > 400 or sweep < 0:
                step = -step
            freq = base + sweep

            if time.ticks_diff(now, last_flash) >= 60:
                last_flash = now
                r, b = pattern[p_idx]
                red.value(r)
                blue.value(b)
                p_idx = (p_idx + 1) % len(pattern)
        else:
            sweep = 0
            freq = base
            red.value(0)
            blue.value(0)
            p_idx = 0

        buzzer.freq(freq)
        buzzer.duty(300)

    print("pot:", raw, " ldr:", val, " dark:", is_dark)
    time.sleep_ms(delay_ms)
