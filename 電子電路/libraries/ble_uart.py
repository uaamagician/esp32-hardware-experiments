from machine import Pin, Timer
from time import sleep_ms
import bluetooth

class BLE_UART:

    def __init__(self, name):

        print("等待手機連線中...")

        self.conn = False

        self.conn_handle = None

        self.name = name

        self.new = False
        self.message = ""

        self.ble = bluetooth.BLE()

        self.ble.active(True)

        self.led = Pin(5, Pin.OUT)

        self.timer1 = Timer(0)
        self.timer2 = Timer(1)

        self.register()

        self.ble.irq(self.ble_irq)

        self.disconnected()

        self.advertiser()

    def connected(self):

        self.conn = True

        self.timer1.deinit()
        self.timer2.deinit()

        self.led.value(0)

    def disconnected(self):

        self.conn = False

        self.timer1.deinit()
        self.timer2.deinit()

        self.timer1.init(
            period=1000,
            mode=Timer.PERIODIC,
            callback=lambda t: self.led.value(0)
        )

        sleep_ms(200)

        self.timer2.init(
            period=1000,
            mode=Timer.PERIODIC,
            callback=lambda t: self.led.value(1)
        )

    def ble_irq(self, event, data):

        if event == 1:

            self.conn_handle = data[0]

            self.connected()

            print("連線到手機或電腦")

        elif event == 2:

            self.conn_handle = None

            self.disconnected()

            print("中斷連線")

            self.advertiser()

        elif event == 3:

            buffer = self.ble.gatts_read(self.rx)

            try:
                self.message = buffer.decode().strip()
                self.new = True

            except UnicodeError:
                print("接收到無法解碼的資料")

    def register(self):

        NUS_UUID = (
            '6E400001-B5A3-F393-E0A9-E50E24DCCA9E'
        )

        RX_UUID = (
            '6E400002-B5A3-F393-E0A9-E50E24DCCA9E'
        )

        TX_UUID = (
            '6E400003-B5A3-F393-E0A9-E50E24DCCA9E'
        )

        BLE_NUS = bluetooth.UUID(NUS_UUID)

        BLE_RX = (
            bluetooth.UUID(RX_UUID),
            bluetooth.FLAG_WRITE
        )

        BLE_TX = (
            bluetooth.UUID(TX_UUID),
            bluetooth.FLAG_NOTIFY
        )

        BLE_UART_SERVICE = (
            BLE_NUS,
            (BLE_TX, BLE_RX)
        )

        SERVICES = (BLE_UART_SERVICE,)

        ((self.tx, self.rx),) = (
            self.ble.gatts_register_services(SERVICES)
        )

        self.ble.gatts_set_buffer(
            self.rx,
            256,
            True
        )

    def send(self, data):

        if self.conn and self.conn_handle is not None:

            message = str(data).encode() + b'\n'

            self.ble.gatts_notify(
                self.conn_handle,
                self.tx,
                message
            )

    def advertiser(self):

        name = self.name.encode()

        adv_data = (
            bytearray(b'\x02\x01\x06')
            + bytearray((len(name) + 1, 0x09))
            + name
        )

        self.ble.gap_advertise(
            100000,
            adv_data
        )

    def get(self):

        if self.new:

            self.new = False

            return self.message

        return ""

    def close(self):

        self.timer1.deinit()
        self.timer2.deinit()

        self.conn = False
        self.conn_handle = None

        self.ble.gap_advertise(None)
        self.ble.active(False)

        self.led.value(1)

        print("BLE 已關閉")
