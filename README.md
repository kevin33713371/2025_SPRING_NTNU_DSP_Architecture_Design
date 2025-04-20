# 2025_SPRING_NTNU_DSP_Architecture_Design
Repository of 2025 Spring NTNU Course DSP(Digital Signal Processing) Architecture Design

## Midterm Project (Float16 Arithmetic Computation Unit)
The purpose of this project is to use the float16 data type to develop an accelerator that supports Vision Transformer activation computations.
- Float16_adder: An adder designed using the float16 format, utilizing normalization and round-to-nearest-even techniques, can achieve a floating-point result `(float16)` with an error less than `0.2` compared to the true floating-point value `(float32)`.
- Log_scale_mul: A multiplier designed using the float16 format leverages logarithmic and exponential computations by applying log2 and exponentiation transformations to the inputs and outputs, respectively. This approach simplifies multiplication into addition operations and achieves a floating-point result `(float16)` with a relative error of less than `1.9%` compared to the true floating-point value `(float32)`.
- Log_scale_div: A divider designed using the float16 format similarly utilizes logarithmic and exponential computations by applying log2 and exponentiation transformations to the inputs and outputs, respectively. This approach simplifies division into subtraction operations and achieves a floating-point result `(float16)` with a relative error of less than `1.1%` compared to the true floating-point value `(float32)`.
