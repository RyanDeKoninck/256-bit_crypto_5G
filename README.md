# master_thesis: FPGA-based Comparison of AES-256, SNOW-V and ZUC-256 for use in 5G

## Abstract
The emergence of quantum computers implies a significant threat towards the current symmetric-key cryptosystems employed in mobile networks, due to Grover's algorithm. To ensure the security of 5G for the foreseeable future, 3GPP has commenced the standardization of 256-bit symmetric-key cryptosystems. Although multiple implementations of the proposed cryptosystems have already been published, they suffer from a lack of uniformity that hinders their suitability for a direct, impartial comparison. The primary objective of this work is to address the existing gap of comparative analyses, with a focus on hardware implementations. To achieve this goal, this work evaluates FPGA implementations of the proposed 256-bit algorithms, which are based on the SNOW-V, AES-256 and ZUC-256 core primitives, on a single FPGA platform. 

This work concludes that, on the selected target device, the implementation based on AES-256 is mostly superior for short messages with respect to throughput and hardware efficiency. Moreover, the implementation based on SNOW-V shows the highest throughput and hardware efficiency for longer messages. To be precise, the AES-256-based implementation shows dominance with respect to throughput and hardware efficiency for messages up to 384 and 128 bits respectively in encryption-only mode. In authentication-only mode, the AES-256-based implementation achieves the highest throughput up to 128 bits, and its hardware efficiency is comparable to that of the SNOW-V-based implementation up to 128 bits. Remarkably, despite not demonstrating optimal performance for complete implementations, ZUC-256 does show the highest hardware efficiency for encryption-only implementations. This observation shows that the implementation based on ZUC-256 is limited in hardware efficiency by its MAC implementation, which consumes more than twice the area of its keystream generator.

## Repository Outline
This repository contains Verilog implementations, testbenches, and C-code to utilize the interface between hardware and software for each of the symmetric-key ciphers under investigation:
```bash
.
├── aes_impl
│   ├── aes
│   │   ├── rtl             -> Verilog implementation for AES-256 (both CTR-mode and CMAC)
│   │   └── tb
│   └── aes_sw_interface
├── snow-v_impl
│   ├── snow-v
│   │   ├── rtl             -> Verilog implementation for SNOW-V (adjusted GCM)
│   │   └── tb
│   └── snow-v_sw_interface
├── zuc-256_impl
│   ├── zuc-256
│   │   ├── rtl             -> Verilog implementation for ZUC-256 (CTR-mode and proprietary MAC)
│   │   └── tb
│   ├── zuc-256_sw_interface
│   └── zuc-256-keygen_ref.c
├── .gitignore
└── README.md
```

[//]: # (## Badges)
[//]: # (On some READMEs, you may see small images that convey metadata, such as whether or not all the tests are passing for the project. You can use Shields to add some to your README. Many services also have instructions for adding a badge.)

[//]: # (## Visuals)
[//]: # (Depending on what you are making, it can be a good idea to include screenshots or even a video -you'll frequently see GIFs rather than actual videos-. Tools like ttygif can help, but check out Asciinema for a more sophisticated method.)

[//]: # (## Installation
Within a particular ecosystem, there may be a common way of installing things, such as using Yarn, NuGet, or Homebrew. However, consider the possibility that whoever is reading your README is a novice and would like more guidance. Listing specific steps helps remove ambiguity and gets people to using your project as quickly as possible. If it only runs in a specific context like a particular programming language version or operating system or has dependencies that have to be installed manually, also add a Requirements subsection.)

[//]: # (## Usage)
[//]: # (Use examples liberally, and show the expected output if you can. It's helpful to have inline the smallest example of usage that you can demonstrate, while providing links to more sophisticated examples if they are too long to reasonably include in the README.)

## Acknowledgments
The Verilog RTL code and testbenches are all based on the work from Joachim Strömbergson, which can be found on his [Github page](https://github.com/secworks). The AES and CMAC cores have been copied from his work, and the coding style of the other RTL modules and testbenches are based on the style used in the aforementioned cores.

[//]: # (## License)
[//]: # (KU Leuven License?)

[//]: # (## Project status)
[//]: # (...)
