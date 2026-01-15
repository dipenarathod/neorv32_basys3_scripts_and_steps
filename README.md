- ada_ml_library: Ada library wrapper to use hardware NPU functions + helper functions to beautify data
- test_cases_neorv32: Ada Test cases file for NEORV32
- mnist_test: Python model for MNIST digit dataset
- wishbone_peripherals: NPUs with various layers
- GTKWave_Test/wb_activation_gtkwave_relu_test: A testbench for the wb_activation peripheral. Aims to measure the cycle overhead added by the NEORV32 and application
- basys3-block-design-setup: (IGNORE): NEORV32 + CLK block design in Vivado

- VHDL Formatter: https://g2384.github.io/VHDLFormatter/

### Commands for building the NEORV32 exe file from Ada programs (using the test_cases_neorv32 project as an example)
- alr build
- riscv64-elf-objcopy -O binary bin/test_cases_neorv32 bin/test_cases_neorv32.bin
- image_gen -app_bin bin/test_cases_neorv32.bin bin/test_cases_neorv32.exeriscv64-elf-objcopy -O binary bin/test_cases_neorv32 bin/test_cases_neorv32.bin
#### Requires the image_gen tool to be in path
