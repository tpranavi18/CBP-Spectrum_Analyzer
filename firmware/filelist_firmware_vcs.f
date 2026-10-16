# ==============================================================================
# CBP-SPECTRUM_ANALYZER — Dedicated Firmware-Driven VCS Filelist
# Target Testbench: tb_firmware_driven
# Location: /home/student/Documents/CBP-Spectrum_Analyzer/firmware/filelist_firmware_vcs.f
# Execute from: /home/student/Documents/CBP-Spectrum_Analyzer/firmware
# ==============================================================================

# Simulation Defines
+define+SIMULATION
+define+RV_BUILD_AXI4
+define+RV_FPGA_OPTIMIZE

# Top-Level Testbench Module Specification
-top tb_firmware_driven

# Include Directories
+incdir+../rtl/Cores-VeeR-EL2/snapshots/spectrum_analyzer
+incdir+../rtl/Cores-VeeR-EL2/configs/snapshots/spectrum_analyzer
+incdir+../rtl/Cores-VeeR-EL2/design/include
+incdir+../rtl/uart/include

# ==============================================================================
# 1. VeeR EL2 Core RTL Design Files (in strict compilation order)
# ==============================================================================
../rtl/Cores-VeeR-EL2/snapshots/spectrum_analyzer/common_defines.vh
../rtl/Cores-VeeR-EL2/design/include/el2_def.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_assert.sv
../rtl/Cores-VeeR-EL2/design/el2_mubi_pkg.sv
../rtl/Cores-VeeR-EL2/design/el2_lockstep_pkg.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_lib.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_mem_if.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_prim_generic_buf.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_prim_buf.sv
../rtl/Cores-VeeR-EL2/design/lib/beh_lib.sv
../rtl/Cores-VeeR-EL2/design/lib/mem_lib.sv
../rtl/Cores-VeeR-EL2/design/lib/ahb_to_axi4.sv
../rtl/Cores-VeeR-EL2/design/lib/axi4_to_ahb.sv
../rtl/Cores-VeeR-EL2/design/el2_mem.sv
../rtl/Cores-VeeR-EL2/design/el2_pic_ctrl.sv
../rtl/Cores-VeeR-EL2/design/el2_dma_ctrl.sv
../rtl/Cores-VeeR-EL2/design/el2_pmp.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_aln_ctl.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_compress_ctl.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_ifc_ctl.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_bp_ctl.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_ic_mem.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_mem_ctl.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_iccm_mem.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec_decode_ctl.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec_gpr_ctl.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec_ib_ctl.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec_pmp_ctl.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec_tlu_ctl.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec_trigger.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec.sv
../rtl/Cores-VeeR-EL2/design/exu/el2_exu_alu_ctl.sv
../rtl/Cores-VeeR-EL2/design/exu/el2_exu_mul_ctl.sv
../rtl/Cores-VeeR-EL2/design/exu/el2_exu_div_ctl.sv
../rtl/Cores-VeeR-EL2/design/exu/el2_exu.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_clkdomain.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_addrcheck.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_lsc_ctl.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_stbuf.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_bus_buffer.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_bus_intf.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_ecc.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_dccm_mem.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_dccm_ctl.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_trigger.sv
../rtl/Cores-VeeR-EL2/design/dbg/el2_dbg.sv
../rtl/Cores-VeeR-EL2/design/dmi/dmi_mux.v
../rtl/Cores-VeeR-EL2/design/dmi/dmi_wrapper.v
../rtl/Cores-VeeR-EL2/design/dmi/dmi_jtag_to_core_sync.v
../rtl/Cores-VeeR-EL2/design/dmi/rvjtag_tap.v
../rtl/Cores-VeeR-EL2/design/el2_veer.sv
../rtl/Cores-VeeR-EL2/design/el2_veer_lockstep.sv
../rtl/Cores-VeeR-EL2/design/el2_veer_wrapper.sv

# ==============================================================================
# 2. Processor Subsystem Infrastructure (Wrapper, Adapters, Memories)
# ==============================================================================
../rtl/veer_wrapper.sv
../rtl/axi_64to32_adapter.sv
../rtl/axi_imem_slave.sv
../rtl/axi_dmem_slave.sv

# ==============================================================================
# 3. Shared 3x18 AXI Interconnect Fabric
# ==============================================================================
../rtl/interconnect/arbiter.v
../rtl/interconnect/priority_encoder.v
../rtl/interconnect/axi_interconnect.v
../rtl/interconnect/axi_interconnect_wrap_3x18.v

# ==============================================================================
# 4. Common AXI Support & Dummy DECERR Slaves
# ==============================================================================
../rtl/common/axi4lite_slave_adapter.sv
../rtl/common/axi4_to_axi4lite_bridge.sv
../rtl/common/axi_dummy_slave.sv

# ==============================================================================
# 5. Spectrum Analyzer Peripheral IPs
# ==============================================================================
# UART (M00: 0x4000_0000)
../rtl/uart/axi_internal_fifo.v
../rtl/uart/uart_parity_bit_compute.v
../rtl/uart/uart_receiver.v
../rtl/uart/uart_transmitter.v
../rtl/uart/uart_controller.v
../rtl/uart/axi_uart_top.v

# GPIO (M01: 0x4000_2000)
../rtl/gpio/gpio_bit.sv
../rtl/gpio/gpio_regs.sv
../rtl/gpio/gpio_wrapper.sv
../rtl/gpio/gpio_axi.sv

# TIMER (M02: 0x4000_4000)
../rtl/timer/timer_core.sv
../rtl/timer/timer_regs.sv
../rtl/timer/timer_axi.sv

# FIR (M03: 0x4000_C000)
../rtl/fir/axis_fifo.v
../rtl/fir/fir_dsp.v
../rtl/fir/fir_axi_lite.v
../rtl/fir/fir_top.v

# ADC (M04: 0x4000_E000)
../rtl/adc/adc_pkg.sv
../rtl/adc/adc_fifo.sv
../rtl/adc/adc_sample_acquisition.sv
../rtl/adc/adc_sampling_scheduler.sv
../rtl/adc/adc_registers.sv
../rtl/adc/adc_axi_lite_slave.sv
../rtl/adc/adc_controller.sv

# NEXHUS FFT (M05: Control at 0x4000_8000, M06: Memory at 0x4000_A000)
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

# ==============================================================================
# 6. Integrated SoC Top Modules
# ==============================================================================
../rtl/veerall_axi_ips_top.sv
../rtl/veerall_top.sv

# ==============================================================================
# 7. Dedicated Integration Components and Testbench
# ==============================================================================
dsp_pipeline_bridge.sv
tb_firmware_driven.sv

