from machine import Pin, PWM, ADC
import time

led_pwm = PWM(Pin(2), freq=5000)
buzzer = PWM(Pin(25), freq=1000)
buzzer.duty(0)
red = Pin(4, Pin.OUT)
blue = Pin(16, Pin.OUT)
red.value(0)
blue.value(0)

pot = ADC(Pin(34))
pot.atten(ADC.ATTN_11DB)

delay_ms = 15
sweep = 0
step = 40

pattern = [(1,0),(0,0),(1,0),(0,0),(0,1),(0,0),(0,1),(0,0)]
p_idx = 0
last_flash = time.ticks_ms()

try:
    while True:
        raw = pot.read_u16()
        duty = raw >> 6
        led_pwm.duty(duty)

        now = time.ticks_ms()

        if duty < 30:
            buzzer.duty(0)
            red.value(0)
            blue.value(0)
        else:
            base = 200 + raw // 65

            if duty > 700:
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

        print("可變電阻:", raw, " 亮度:", duty)
        time.sleep_ms(delay_ms)
except KeyboardInterrupt:
    led_pwm.duty(0)
    buzzer.duty(0)
    red.value(0)
    blue.value(0)
    led_pwm.deinit()
    buzzer.deinit()
    print("測試結束")
