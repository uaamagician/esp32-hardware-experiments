from machine import Pin, PWM, ADC
import time

led_pwm = PWM(Pin(2), freq=5000)
buzzer = PWM(Pin(25), freq=1000)
buzzer.duty(0)

pot = ADC(Pin(34))
pot.atten(ADC.ATTN_11DB)

delay_ms = 15

try:
    while True:
        raw = pot.read_u16()
        duty = raw >> 6
        led_pwm.duty(duty)
        buzzer.duty(duty // 2)
        print("可變電阻:", raw, " 亮度:", duty)
        time.sleep_ms(delay_ms)
except KeyboardInterrupt:
    led_pwm.duty(0)
    buzzer.duty(0)
    led_pwm.deinit()
    buzzer.deinit()
    print("測試結束")
