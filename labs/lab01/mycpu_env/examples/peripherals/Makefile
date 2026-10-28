LLVM_BIN ?= /opt/homebrew/opt/llvm/bin
MC := $(LLVM_BIN)/llvm-mc
OBJCOPY := $(LLVM_BIN)/llvm-objcopy

.PHONY: all clean
all: peripheral_demo.hex uart_echo.hex perf_demo.hex

peripheral_demo.o: peripheral_demo.S
	$(MC) -triple=loongarch32-unknown-elf -filetype=obj -o $@ $<

peripheral_demo.bin: peripheral_demo.o
	$(OBJCOPY) -O binary --only-section=.text $< $@

peripheral_demo.hex: peripheral_demo.bin bin2hex.py
	python3 bin2hex.py $< $@

uart_echo.o: uart_echo.S
	$(MC) -triple=loongarch32-unknown-elf -filetype=obj -o $@ $<

uart_echo.bin: uart_echo.o
	$(OBJCOPY) -O binary --only-section=.text $< $@

uart_echo.hex: uart_echo.bin bin2hex.py
	python3 bin2hex.py $< $@

perf_demo.o: perf_demo.S
	$(MC) -triple=loongarch32-unknown-elf -filetype=obj -o $@ $<

perf_demo.bin: perf_demo.o
	$(OBJCOPY) -O binary --only-section=.text $< $@

perf_demo.hex: perf_demo.bin bin2hex.py
	python3 bin2hex.py $< $@

clean:
	rm -f peripheral_demo.o peripheral_demo.bin peripheral_demo.hex \
	      uart_echo.o uart_echo.bin uart_echo.hex \
	      perf_demo.o perf_demo.bin perf_demo.hex
