// ============================================================
// UART + AXI INTERCONNECT + NEXHUS FFT INTEGRATION
// ============================================================

// -------------------- UART --------------------
+incdir+../rtl/uart/include

../rtl/uart/axi_internal_fifo.v
../rtl/uart/uart_parity_bit_compute.v
../rtl/uart/uart_receiver.v
../rtl/uart/uart_transmitter.v
../rtl/uart/uart_controller.v
../rtl/uart/axi_uart_top.v


// -------------------- AXI INTERCONNECT --------------------
../rtl/interconnect/axi_interconnect.v
../rtl/interconnect/axi_interconnect_wrap_3x14.v
../rtl/interconnect/arbiter.v
../rtl/interconnect/priority_encoder.v


// -------------------- NEXHUS FFT --------------------
// Simulation-only replacement for Xilinx XPM memory
../rtl/fft_nexhus/xpm_memory_tdpram_model.sv

../rtl/fft_nexhus/add_sub_sat_s1_q15.sv
../rtl/fft_nexhus/bram_memeory.sv
../rtl/fft_nexhus/cmulq15.sv
../rtl/fft_nexhus/fft_atomic_p1.sv
../rtl/fft_nexhus/fft_ctrl_axil.sv
../rtl/fft_nexhus/fft_loadstore_wrapper.sv
../rtl/fft_nexhus/fft_mem_axi4_slave.sv
../rtl/fft_nexhus/fft_stage_core.sv
../rtl/fft_nexhus/fft_stage_core_controller.sv
../rtl/fft_nexhus/fft_top.sv
../rtl/fft_nexhus/twiddle_rom.sv
../rtl/fft_nexhus/fft_accel_fft_top.sv


// -------------------- FIR --------------------
../rtl/fir/axis_fifo.v
../rtl/fir/fir_dsp.v
../rtl/fir/fir_axi_lite.v
../rtl/fir/fir_top.v


// -------------------- ADC --------------------
../rtl/adc/adc_pkg.sv
../rtl/adc/adc_fifo.sv
../rtl/adc/adc_sample_acquisition.sv
../rtl/adc/adc_sampling_scheduler.sv
../rtl/adc/adc_registers.sv
../rtl/adc/adc_axi_lite_slave.sv
../rtl/adc/adc_controller.sv



// -------------------- COMMON AXI FILES --------------------
../rtl/common/axi4lite_slave_adapter.sv
../rtl/common/axi4_to_axi4lite_bridge.sv



// -------------------- GPIO --------------------
../rtl/gpio/gpio_bit.sv
../rtl/gpio/gpio_regs.sv
../rtl/gpio/gpio_wrapper.sv
../rtl/gpio/gpio_axi.sv

// -------------------- TIMER --------------------
../rtl/timer/timer_core.sv
../rtl/timer/timer_regs.sv
../rtl/timer/timer_axi.sv



// -------------------- COMBINED SOC TOP --------------------
../rtl/uart_fft_fir_adc_gpio_timer_top.sv


// -------------------- COMBINED SOC TESTBENCH --------------------
../tb/tb_soc_uart_fft_fir_adc_gpio_timer.sv




