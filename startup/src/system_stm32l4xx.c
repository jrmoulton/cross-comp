/**
 ******************************************************************************
 * @file    system_stm32l4xx.c
 * @author  MCD Application Team
 * @brief   CMSIS Cortex-M4 Device Peripheral Access Layer System Source File
 *
 *   This file provides two functions and one global variable to be called from
 *   user application:
 *      - SystemInit(): This function is called at startup just after reset and
 *                      before branch to main program. This call is made inside
 *                      the "startup_stm32l4xx.s" file.
 *
 *      - SystemCoreClock variable: Contains the core clock (HCLK), it can be
 *used by the user application to setup the SysTick timer or configure other
 *parameters.
 *
 *      - SystemCoreClockUpdate(): Updates the variable SystemCoreClock and must
 *                                 be called whenever the core clock is changed
 *                                 during program execution.
 *
 *   After each device reset the MSI (4 MHz) is used as system clock source.
 *   Then SystemInit() function is called, in "startup_stm32l4xx.s" file, to
 *   configure the system clock before to branch to main program.
 *
 *   This file configures the system clock as follows:
 *=============================================================================
 *-----------------------------------------------------------------------------
 *        System Clock source                    | MSI
 *-----------------------------------------------------------------------------
 *        SYSCLK(Hz)                             | 4000000
 *-----------------------------------------------------------------------------
 *        HCLK(Hz)                               | 4000000
 *-----------------------------------------------------------------------------
 *        AHB Prescaler                          | 1
 *-----------------------------------------------------------------------------
 *        APB1 Prescaler                         | 1
 *-----------------------------------------------------------------------------
 *        APB2 Prescaler                         | 1
 *-----------------------------------------------------------------------------
 *        PLL_M                                  | 1
 *-----------------------------------------------------------------------------
 *        PLL_N                                  | 8
 *-----------------------------------------------------------------------------
 *        PLL_P                                  | 7
 *-----------------------------------------------------------------------------
 *        PLL_Q                                  | 2
 *-----------------------------------------------------------------------------
 *        PLL_R                                  | 2
 *-----------------------------------------------------------------------------
 *        PLLSAI1_P                              | NA
 *-----------------------------------------------------------------------------
 *        PLLSAI1_Q                              | NA
 *-----------------------------------------------------------------------------
 *        PLLSAI1_R                              | NA
 *-----------------------------------------------------------------------------
 *        PLLSAI2_P                              | NA
 *-----------------------------------------------------------------------------
 *        PLLSAI2_Q                              | NA
 *-----------------------------------------------------------------------------
 *        PLLSAI2_R                              | NA
 *-----------------------------------------------------------------------------
 *        Require 48MHz for USB OTG FS,          | Disabled
 *        SDIO and RNG clock                     |
 *-----------------------------------------------------------------------------
 *=============================================================================
 ******************************************************************************
 * @attention
 *
 * <h2><center>&copy; Copyright (c) 2017 STMicroelectronics.
 * All rights reserved.</center></h2>
 *
 * This software component is licensed by ST under Apache License, Version 2.0,
 * the "License"; You may not use this file except in compliance with the
 * License. You may obtain a copy of the License at:
 *                        opensource.org/licenses/Apache-2.0
 *
 ******************************************************************************
 */

#include "stm32l4_clocks.h"
#include "stm32l4xx.h"

// Uncomment the following line to relocate vector table in internal SRAM
// #define VECT_TAB_SRAM

// Vector Table base offset field (this value must be a multiple of 0x200)
#define VECT_TAB_OFFSET 0x00

// The core clock frequency (HCLK, Hz)
uint32_t SystemCoreClock = MSI_VALUE;

// AHB prescalers
const uint8_t AHBPrescTable[16] = {0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U,
                                   1U, 2U, 3U, 4U, 6U, 7U, 8U, 9U};

// APB prescalers
const uint8_t APBPrescTable[8] = {0U, 0U, 0U, 0U, 1U, 2U, 3U, 4U};

// Available MSI frequency ranges (Hz)
const uint32_t MSIRangeTable[12] = {100000U,   200000U,   400000U,   800000U,
                                    1000000U,  2000000U,  4000000U,  8000000U,
                                    16000000U, 24000000U, 32000000U, 48000000U};

// Setup the microcontroller system (reset the clocks to the default reset
// state)
void SystemInit(void) {
#if (__FPU_PRESENT == 1) && (__FPU_USED == 1)
    // FPU settings
    SCB->CPACR |= (0xFU << 20); // Enable CP10, CP11
#endif

    // Set MSION bit
    RCC->CR |= RCC_CR_MSION;

    // Reset CFGR register
    RCC->CFGR = 0x00000000U;

    // Reset HSEON, CSSON , HSION, and PLLON bits
    RCC->CR &= 0xEAF6FFFFU;

    // Reset PLLCFGR register
    RCC->PLLCFGR = 0x00001000U;

    // Reset HSEBYP bit
    RCC->CR &= 0xFFFBFFFFU;

    // Disable all interrupts
    RCC->CIER = 0x00000000U;

    // Configure the vector table location add offset address
#ifdef VECT_TAB_SRAM
    SCB->VTOR = SRAM_BASE | VECT_TAB_OFFSET; // table in internal SRAM
#else
    SCB->VTOR = FLASH_BASE | VECT_TAB_OFFSET; // table in Internal FLASH
#endif
}

// Calculate the value of SystemCoreClock according to clock register values
// note:
//   - The result of this function could be not correct when using fractional
//     value for HSE crystal.
//   - This function must be called whenever the core clock is changed
//     during program execution
void SystemCoreClockUpdate(void) {
    uint32_t msirange;
    uint32_t tmp;

    // MSI frequency (Hz)
    if (RCC->CR & RCC_CR_MSIRGSEL) {
        // MSIRGSEL=1 --> MSIRANGE from RCC_CR applies
        msirange =
            MSIRangeTable[(RCC->CR & RCC_CR_MSIRANGE) >> RCC_CR_MSIRANGE_Pos];
    } else {
        // MSIRGSEL=0 --> MSISRANGE from RCC_CSR applies
        msirange = MSIRangeTable[(RCC->CSR & RCC_CSR_MSISRANGE) >>
                                 RCC_CSR_MSISRANGE_Pos];
    }

    // SYSCLK source
    switch (RCC->CFGR & RCC_CFGR_SWS) {
    case RCC_CFGR_SWS_HSI:
        // HSI used as system clock source
        SystemCoreClock = HSI_VALUE;
        break;
    case RCC_CFGR_SWS_HSE:
        // HSE used as system clock source
        SystemCoreClock = HSE_VALUE;
        break;
    case RCC_CFGR_SWS_PLL:
        // PLL used as system clock source

        // PLLM division factor
        tmp = ((RCC->PLLCFGR & RCC_PLLCFGR_PLLM) >> RCC_PLLCFGR_PLLM_Pos) + 1;

        // PLL source
        switch (RCC->PLLCFGR & RCC_PLLCFGR_PLLSRC) {
        case RCC_PLLCFGR_PLLSRC_HSI:
            // HSI used as PLL clock source
            SystemCoreClock = (HSI_VALUE / tmp);
            break;
        case RCC_PLLCFGR_PLLSRC_HSE:
            // HSE used as PLL clock source
            SystemCoreClock = (HSE_VALUE / tmp);
            break;
        case RCC_PLLCFGR_PLLSRC_MSI:
        default:
            // MSI used as PLL clock source
            SystemCoreClock = (msirange / tmp);
            break;
        }

        // PLL_VCO = (HSE_VALUE or HSI_VALUE or MSI_VALUE/PLLM) * PLLN
        // SYSCLK = PLL_VCO / PLLR
        SystemCoreClock *=
            (RCC->PLLCFGR & RCC_PLLCFGR_PLLN) >> RCC_PLLCFGR_PLLN_Pos;
        SystemCoreClock /=
            (((RCC->PLLCFGR & RCC_PLLCFGR_PLLR) >> RCC_PLLCFGR_PLLR_Pos) + 1)
            << 1;

        break;
    case RCC_CFGR_SWS_MSI:
    default:
        // MSI used as system clock source
        SystemCoreClock = msirange;

        break;
    }

    // HCLK clock frequency
    SystemCoreClock >>=
        AHBPrescTable[((RCC->CFGR & RCC_CFGR_HPRE) >> RCC_CFGR_HPRE_Pos)];
}