/*****************************************************************************/
/**
 *
 * @file sound_capture_transfer_main.c
 *
 * This file contains the implementation of chapter 9 specific code for
 * the example.
 *
 *****************************************************************************/

/***************************** Include Files ********************************/
#include "xparameters.h"

#include "xusbps_ch9_audio.h"
#include "xusbps_class_audio.h"

#include "xil_exception.h"
#include "xpseudo_asm.h"
#include "xreg_cortexa9.h"
#include "xil_cache.h"
#include <xil_printf.h>
#include "xinterrupt_wrap.h"
#include <stdio.h>
#include <xgpio_l.h>
#include <xparameters_ps.h>
#include <xscugic.h>
#include <xstatus.h>
#include "platform.h"
#include "xgpio.h"
#include "xplatform_info.h"
#include "xiicps.h"
#include "xgpiops.h"
#include <sleep.h>
#include "xscutimer.h"


/************************** Constant Definitions ****************************/
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))

/*
 * The following constants are to be modified to get different size of memory.
 */
#define RAMDISKSECTORS  	0x400		//1KB
#define RAMBLOCKS		4096

#define MEMORY_SIZE (64 * 1024)
#ifdef __ICCARM__
#pragma data_alignment = 32
u8 Buffer[MEMORY_SIZE];
#pragma data_alignment = 4
#else
u8 Buffer[MEMORY_SIZE] ALIGNMENT_CACHELINE;
#endif

/*
 * Default is 8000Hz
 * Change this value to set different sampling rate.
 * 		u8 AudioFreq [MAX_AudioFreq][3] ={
 * 			{ 0x40, 0x1F, 0x00 }, // sample frequency 8000
 * 			{ 0x44, 0xAC, 0x00 }, // sample frequency 44100
 * 			{ 0x80, 0xBB, 0x00 }, // sample frequency 48000
 * 			{ 0x00, 0x77, 0x01,}, // sample frequency 96000
 *		};
 */
#define CUR_AUDIOFREQ		0x03


/********************** register and setup shortcuts *************************/
#define LED0    11
#define LED1    12
#define LED2    15
#define LED3    14
#define LED4    9
#define LED5    0
#define LED6    13
#define LED7    10
#define	XGPIOPS_BASEADDR	XPAR_XGPIOPS_0_BASEADDR
#define XIICPS_BASEADDRESS	XPAR_XIICPS_0_BASEADDR
#define IIC_SCLK_RATE		100000
#define IIC_BUFFER_SIZE     2
#define	XGPIO0_AXI_BASEADDRESS	XPAR_AXI_GPIO_0_BASEADDR
#define	XGPIO1_AXI_BASEADDRESS	XPAR_AXI_GPIO_1_BASEADDR
#define	XGPIO2_AXI_BASEADDRESS	XPAR_AXI_GPIO_2_BASEADDR
#define	XGPIO3_AXI_BASEADDRESS	XPAR_AXI_GPIO_3_BASEADDR
#define	XGPIO4_AXI_BASEADDRESS	XPAR_AXI_GPIO_4_BASEADDR
#define	XGPIO5_AXI_BASEADDRESS	XPAR_AXI_GPIO_5_BASEADDR
#define	XGPIO7_AXI_BASEADDRESS	XPAR_AXI_GPIO_7_BASEADDR
#define	XGPIO8_AXI_BASEADDRESS	XPAR_AXI_GPIO_8_BASEADDR
#define XGPIO_AXI_DATA_ADDR0    0x0000
#define XGPIO_AXI_DATA_ADDR1    0x0008
#define buff_p  1000
#define buff_f  100000
#define TIMER_LOAD_VALUE    0x7FFFFFF
#define	XSCUTIMER_BASEADDR  XPAR_SCUTIMER_BASEADDR
#define interruptID_use 61
#define USBPS_BASEADDR		XPS_USB0_BASEADDR
#define XUSB_INT_ID         XPS_USB0_INT_ID

/************************** Function Prototypes ******************************/
static void XUsbPs_IsoInHandler(void *CallBackRef, u32 RequestedBytes,
				u32 BytesTxed );
static void XUsbPs_IsoOutHandler(void *CallBackRef, u32 RequestedBytes,
				 u32 BytesTxed );
static void XUsbPs_AudioTransferSize(void);
static void XUsbPs_Ep0EventHandler(void *CallBackRef, u8 EpNum, u8 EventType);
s32 XUsbPs_CfgInit(struct Usb_DevData *InstancePtr, Usb_Config *ConfigPtr,
		   u32 BaseAddress);

/************************** Variable Definitions *****************************/
struct Usb_DevData UsbInstance;

static XScuGic intc;
XGpio   Gpio0;
XGpio   Gpio1;
XGpio   Gpio2;
XGpio   Gpio3;
XGpio   Gpio4;
XGpio   Gpio5;
XGpio   Gpio7;
XGpio   Gpio8;
XIicPs Iic;
XGpioPs Gpiops;
XScuTimer TimerInstance;
Usb_Config *UsbConfigPtr;
XUsbPs PrivateData;

XUsbPs_DeviceConfig DeviceConfig;

/************************** Function Prototypes ******************************/
int init_gpio();
int init_intr();
static void IntrHandler();
void flush_buffer(void);
void clear_buffer(void);
int init_iic();
void check_state(void);
void write_LED(int led);
static void TimerIntrHandler();
int init_timer();

/************************** Variable Definitions *****************************/
int ind_p = 0;
int ind_f = 0;
u8 buffer_p[buff_p];
u32 buffer1[buff_f];
u32 buffer2[buff_f];
int flushing = 0;
u8 SendBuffer[IIC_BUFFER_SIZE];
u8 RecvBuffer[IIC_BUFFER_SIZE-1];
u8 RecvAddrBuffer[1];

int gpio_reg = XGPIO_AXI_DATA_ADDR0;
int gpio_sel = XGPIO0_AXI_BASEADDRESS;
int gpio_w_sel = XGPIO2_AXI_BASEADDRESS;
int mic_g = 0;

/*
 * A ram array
 */
u32 RamDisk[RAMDISKSECTORS * RAMBLOCKS] __attribute__ ((aligned(4)));
u8 *WrRamDiskPtr = (u8 *) & (RamDisk[0]);

u8 BufferPtrTemp[1024];

u32 Index = 0;
u8 FirstPktFrame = 1;

u32 Framesize = 0, Interval = 0, PacketSize = 0,
    PacketResidue = 0, Residue = 0;

static u32 FileSize = sizeof(buffer_p);

/* Supported AUDIO sampling frequencies */
u8 AudioFreq [MAX_AUDIO_FREQ][3] = {
	{ 0x40, 0x1F, 0x00 },	/* sample frequency 8000  */
	{ 0x44, 0xAC, 0x00 },	/* sample frequency 44100 */
	{ 0x80, 0xBB, 0x00 },	/* sample frequency 48000 */
	{ 0x00, 0x77, 0x01,},	/* sample frequency 96000 */
};

/****************************************************************************/
/**
 * This function is the main function
 *
 * @param	None
 *
 * @return
 *		- XST_SUCCESS if successful,
 *		- XST_FAILURE if unsuccessful.
 *
 * @note	None.
 *
 *
 *****************************************************************************/
int main(void)
{
	const u8 NumEndpoints = 2;
	u8 *MemPtr = NULL;
	s32 Status;

    // setup system
    print("\r\n\r\n");

    print("Microphone array setup!\n\r");
    
    init_platform();

    clear_buffer();

    Status = init_gpio();
    if (Status != XST_SUCCESS) {
         return XST_FAILURE;
    }

    Status = init_iic();
    if (Status != XST_SUCCESS) {
         return XST_FAILURE;
    }

    Status = init_intr();
    if (Status != XST_SUCCESS) {
         return XST_FAILURE;
    }

    Status = init_timer();
    if (Status != XST_SUCCESS) {
         return XST_FAILURE;
    }


    // setup USB system
	UsbConfigPtr = XUsbPs_LookupConfig(USBPS_BASEADDR);

	if (NULL == UsbConfigPtr) {
		return XST_FAILURE;
	}

	Status = XUsbPs_CfgInit(&UsbInstance, UsbConfigPtr,
				UsbConfigPtr->BaseAddress);
	if (XST_SUCCESS != Status) {
		return XST_FAILURE;
	}

	/*
	 * Assign the ep configuration to USB driver
	 */

	DeviceConfig.EpCfg[0].Out.Type = XUSBPS_EP_TYPE_CONTROL;
	DeviceConfig.EpCfg[0].Out.NumBufs = 2;
	DeviceConfig.EpCfg[0].Out.BufSize = 64;
	DeviceConfig.EpCfg[0].Out.MaxPacketSize = 64;
	DeviceConfig.EpCfg[0].In.Type = XUSBPS_EP_TYPE_CONTROL;
	DeviceConfig.EpCfg[0].In.NumBufs = 2;
	DeviceConfig.EpCfg[0].In.MaxPacketSize = 64;

	DeviceConfig.EpCfg[1].Out.Type = XUSBPS_EP_TYPE_ISOCHRONOUS;
	DeviceConfig.EpCfg[1].Out.NumBufs = 16;
	DeviceConfig.EpCfg[1].Out.BufSize = 1024;
	DeviceConfig.EpCfg[1].Out.MaxPacketSize = 1024;
	DeviceConfig.EpCfg[1].In.Type = XUSBPS_EP_TYPE_ISOCHRONOUS;
	DeviceConfig.EpCfg[1].In.NumBufs = 16;
	DeviceConfig.EpCfg[1].In.MaxPacketSize = 1024;

	DeviceConfig.NumEndpoints = NumEndpoints;

	MemPtr = (u8 *) &Buffer[0];
	memset(MemPtr, 0, MEMORY_SIZE);
	Xil_DCacheFlushRange((unsigned int) MemPtr, MEMORY_SIZE);

	/* Finish the configuration of the DeviceConfig structure and configure
	 * the DEVICE side of the controller.
	 */
	DeviceConfig.DMAMemPhys = (u32) MemPtr;

	Status = XUsbPs_ConfigureDevice(UsbInstance.PrivateData, &DeviceConfig);

	if (XST_SUCCESS != Status) {
		return XST_FAILURE;
	}    

	/*
	 * Hook up chapter9 handler
	 */
	Status = XUsbPs_EpSetHandler(UsbInstance.PrivateData, 0,
				     XUSBPS_EP_DIRECTION_OUT,
				     (XUsbPs_EpHandlerFunc)XUsbPs_Ep0EventHandler,
				     UsbInstance.PrivateData);

	/*
	 * set endpoint handlers
	 * XUsbPsu_IsoInHandler -  to be called when data is sent
	 * XUsbPsu_IsoOutHandler -  to be called when data is received
	 */
	XUsbPs_EpSetIsoHandler(UsbInstance.PrivateData, ISO_EP,
			       XUSBPS_EP_DIRECTION_IN,
			       XUsbPs_IsoInHandler);

	XUsbPs_EpSetIsoHandler(UsbInstance.PrivateData, ISO_EP,
			       XUSBPS_EP_DIRECTION_OUT,
			       XUsbPs_IsoOutHandler);

	/*
	 * Setup interrupts
	 */	
    XScuGic *IntcInstancePtr = &intc;
    Status = XScuGic_Connect(IntcInstancePtr, XPS_USB0_INT_ID,
				(Xil_ExceptionHandler)XUsbPs_IntrHandler,
				(void *)UsbInstance.PrivateData);
    
    XScuGic_Enable(IntcInstancePtr, XPS_USB0_INT_ID);
    
    
	XUsbPs_IntrEnable((XUsbPs *)UsbInstance.PrivateData,
			  XUSBPS_IXR_UR_MASK | XUSBPS_IXR_UI_MASK);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	XUsbPs_AudioTransferSize();

	/*
	 * Start the controller so that Host can see our device
	 */
	XUsbPs_Start((XUsbPs *)UsbInstance.PrivateData);

	while (1) {

        // check if flushing and flush array buffer
        if (flushing == 1)
        {
            flush_buffer();
        }

	}

    cleanup_platform();
    while(1);

	return XST_SUCCESS;
}

/****************************************************************************/
/**
 * This function calculates Data to be sent at every Interval
 *
 * @param	None
 *
 * @return	None
 *
 * @note	None.
 *
 *
 *****************************************************************************/
static void XUsbPs_AudioTransferSize(void)

{
	u32 Rate = 0, AudioFreqTemp = 0, MaxPacketSize = 0;

	/*
	 * Audio sampling frequency which filled in TYPE One Format
	 * descriptors
	 */
	AudioFreqTemp = (u32)((u8)AudioFreq[CUR_AUDIOFREQ][0] |
			      (u8)AudioFreq[CUR_AUDIOFREQ][1] << 8 |
			      (u8)AudioFreq[CUR_AUDIOFREQ][2] << 16);

	/*
	 * Audio transmission Bytes required to send in one sec
	 * (Sampling Freq * Number of Channel * Audio frame size)
	 */
	Framesize = AUDIO_CHANNEL_NUM * AUDIO_FRAME_SIZE;
	Rate = AudioFreqTemp * Framesize;
	Interval = INTERVAL_PER_SECOND / (1 << (AUDIO_INTERVAL - 1));

	/*
	 * Audio data transfer size to be transfered at every interval
	 */
	MaxPacketSize = AUDIO_CHANNEL_NUM * AUDIO_FRAME_SIZE *
			DIV_ROUND_UP(AudioFreqTemp, INTERVAL_PER_SECOND /
				     (1 << (AUDIO_INTERVAL - 1)));
	PacketSize = ((Rate / Interval) < MaxPacketSize) ?
		     (Rate / Interval) : MaxPacketSize;

	if (PacketSize < MaxPacketSize) {
		PacketResidue = Rate % Interval;
	} else {
		PacketResidue = 0;
	}
}

/****************************************************************************/
/**
 * This function is ISO IN Endpoint handler/Callback function, called by driver
 * when data is sent to host.
 *
 * @param	CallBackRef is pointer to Usb_DevData instance.
 * @param	RequestedBytes is number of bytes requested to send.
 * @param	BytesTxed is actual number of bytes sent to Host.
 *
 * @return	None
 *
 * @note	None.
 *
 *****************************************************************************/
static void XUsbPs_IsoInHandler(void *CallBackRef, u32 RequestedBytes,
				u32 BytesTxed)
{
	struct Usb_DevData *InstancePtr = CallBackRef;
	u32 Size;

	Size = PacketSize;
	Residue += PacketResidue;

	if ((Residue / Interval) >= Framesize) {
		Size += Framesize;
		Residue -= Framesize * Interval;
	}

	if ((Index + Size) > FileSize) {
		/* Buffer is completed, retransmitting the same file data */
		Index = 0;
	}
    
	if (XUsbPs_EpBufferSend((XUsbPs *)InstancePtr->PrivateData, ISO_EP,
				&buffer_p[Index],
				Size) == XST_SUCCESS) {
		Index += Size;
		if (FirstPktFrame) {
			Size = PacketSize;
			Residue += PacketResidue;

			if ((Residue / Interval) >= Framesize) {
				Size += Framesize;
				Residue -= Framesize * Interval;
			}

			if ((Index + Size) > FileSize) {
				Index = 0;
			} else {
				Index += Size;
			}

			FirstPktFrame = 0;
		}
	}
}

/****************************************************************************/
/**
 * This function is ISO OUT Endpoint handler/Callback function, called by driver
 * when data is received from host.
 *
 * @param	CallBackRef is pointer to Usb_DevData instance.
 * @param	RequestedBytes is number of bytes requested to send.
 * @param	BytesTxed is actual number of bytes sent to Host.
 *
 * @return	None
 *
 * @note	None.
 *
 *****************************************************************************/
static void XUsbPs_IsoOutHandler(void *CallBackRef, u32 RequestedBytes,
				 u32 BytesTxed)
{
	struct Usb_DevData *InstancePtr = CallBackRef;
	u32 Size;

	Size = PacketSize;
	Residue += PacketResidue;

	if ((Residue / Interval) >= Framesize) {
		Size += Framesize;
		Residue -= Framesize * Interval;
	}

	if (FirstPktFrame) {
		FirstPktFrame = 0;
	} else {
		if ((Index + BytesTxed) > FileSize) {
			/* Buffer is full, overwriting the data */
			Index = 0;
		}

		/* Copy received to RAM array */
		memcpy(&WrRamDiskPtr[Index], BufferPtrTemp, BytesTxed);
		Index += BytesTxed;
	}

	XUsbPs_EpDataBufferReceive((XUsbPs *)InstancePtr->PrivateData, ISO_EP,
				   BufferPtrTemp, Size);
}


/*****************************************************************************/
/**
 * This function is registered to handle callbacks for endpoint 0 (Control).
 *
 * It is called from an interrupt context such that the amount of processing
 * performed should be minimized.
 *
 *
 * @param	CallBackRef is the reference passed in when the function
 *		was registered.
 * @param	EpNum is the Number of the endpoint on which the event occurred.
 * @param	EventType is type of the event that occurred.
 *
 * @return	None.
 *
 ******************************************************************************/
static void XUsbPs_Ep0EventHandler(void *CallBackRef, u8 EpNum, u8 EventType)
{
	XUsbPs *InstancePtr;
	int Status;
	XUsbPs_SetupData SetupData;
	u8 *BufferPtr;
	u32 BufferLen;
	u32 Handle;

	Xil_AssertVoid(NULL != CallBackRef);

	InstancePtr = (XUsbPs *) CallBackRef;


	switch (EventType) {

		/* Handle the Setup Packets received on Endpoint 0. */
		case XUSBPS_EP_EVENT_SETUP_DATA_RECEIVED:
			Status = XUsbPs_EpGetSetupData(InstancePtr, EpNum, &SetupData);
			if (XST_SUCCESS == Status) {
				/* Handle the setup packet. */
				(int) XUsbPs_Ch9HandleSetupPacket((XUsbPs *)InstancePtr,
								  &SetupData);
			}
			break;

		/* We get data RX events for 0 length packets on endpoint 0.
		 * We receive and immediately release them again here, but
		 * there's no action to be taken.
		 */
		case XUSBPS_EP_EVENT_DATA_RX:
			/* Get the data buffer. */
			Status = XUsbPs_EpBufferReceive(InstancePtr, EpNum, &BufferPtr,
							&BufferLen, &Handle);
			if (XST_SUCCESS == Status) {
				/* Return the buffer. */
				XUsbPs_EpBufferRelease(Handle);
			}
			break;

		default:
			/* Unhandled event. Ignore. */
			break;
	}
}

/*****************************************************************************/ 
/** 
 *
 * This function initializes a XUsbPs instance/driver.
 *
 * The initialization entails:
 * - Initialize all members of the XUsbPs structure.
 *
 * @param	InstancePtr is a pointer to XUsbPs instance of the controller.
 * @param	ConfigPtr is a pointer to a XUsbPs_Config configuration
 *		structure. This structure will contain the requested
 *		configuration for the device. Typically, this is a local
 *		structure and the content of which will be copied into the
 *		configuration structure within XUsbPs.
 * @param	BaseAddress is the base address of the device.
 *
 * @return
 *		- XST_SUCCESS no errors occurred.
 *		- XST_FAILURE an error occurred during initialization.
 *
 * @note
 *
******************************************************************************/

s32 XUsbPs_CfgInit(struct Usb_DevData *InstancePtr, Usb_Config *ConfigPtr,
		   u32 BaseAddress)
{
	PrivateData.AppData = InstancePtr;
	InstancePtr->PrivateData = (void *)&PrivateData;

	return XUsbPs_CfgInitialize((XUsbPs *)InstancePtr->PrivateData,
				    ConfigPtr, BaseAddress);
}

/*****************************************************************************/
/**
 * This function initializes axi gpio and PS gpio
 *
 * It setups All axi gpio registers and PS MIO gpio LEDs
 *
 * @return	status of operation
 *
 ******************************************************************************/
int init_gpio()
{
    int Status;
    XGpioPs_Config *ConfigPtr;
    ConfigPtr = XGpioPs_LookupConfig(XGPIOPS_BASEADDR);
    Status = XGpioPs_CfgInitialize(&Gpiops, ConfigPtr,
				       ConfigPtr->BaseAddr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}
    
    // setup axi gpio registers
    Status = XGpio_Initialize(&Gpio0, XGPIO0_AXI_BASEADDRESS);
    Status = XGpio_Initialize(&Gpio1, XGPIO1_AXI_BASEADDRESS);
    Status = XGpio_Initialize(&Gpio2, XGPIO2_AXI_BASEADDRESS);
    Status = XGpio_Initialize(&Gpio3, XGPIO3_AXI_BASEADDRESS);
    Status = XGpio_Initialize(&Gpio4, XGPIO4_AXI_BASEADDRESS);
    Status = XGpio_Initialize(&Gpio5, XGPIO5_AXI_BASEADDRESS);
    Status = XGpio_Initialize(&Gpio7, XGPIO7_AXI_BASEADDRESS);
    Status = XGpio_Initialize(&Gpio8, XGPIO8_AXI_BASEADDRESS);
    if (Status != XST_SUCCESS)
    {
        return XST_FAILURE;
    }

    // setup MIO LEDs 
    XGpioPs_SetDirectionPin(&Gpiops, LED0, 1);
	XGpioPs_SetOutputEnablePin(&Gpiops, LED0, 1);
    XGpioPs_SetDirectionPin(&Gpiops, LED1, 1);
	XGpioPs_SetOutputEnablePin(&Gpiops, LED1, 1);
    XGpioPs_SetDirectionPin(&Gpiops, LED2, 1);
	XGpioPs_SetOutputEnablePin(&Gpiops, LED2, 1);
    XGpioPs_SetDirectionPin(&Gpiops, LED3, 1);
	XGpioPs_SetOutputEnablePin(&Gpiops, LED3, 1);
    XGpioPs_SetDirectionPin(&Gpiops, LED4, 1);
	XGpioPs_SetOutputEnablePin(&Gpiops, LED4, 1);
    XGpioPs_SetDirectionPin(&Gpiops, LED5, 1);
	XGpioPs_SetOutputEnablePin(&Gpiops, LED5, 1);
    XGpioPs_SetDirectionPin(&Gpiops, LED6, 1);
	XGpioPs_SetOutputEnablePin(&Gpiops, LED6, 1);
    XGpioPs_SetDirectionPin(&Gpiops, LED7, 1);
	XGpioPs_SetOutputEnablePin(&Gpiops, LED7, 1);

    printf("Gpio initialization complete.\r\n");

    return XST_SUCCESS;
}

/*****************************************************************************/
/**
 * This function initializes sound chip trough IIC
 *
 * It setups PDM to TDM chip, setup 16 bit data width, 4 channel setup
 * with correct clocking and operation setup
 *
 *
 * @return	status of operation
 *
 ******************************************************************************/
int init_iic()
{
    int addressLookupNum = 10;
    int addressLookup[] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x07, 0x0D, 0x0E, 0x0F, 0x10};

    int Status;
    XIicPs_Config *Config;
    u16 SlaveAddr = 0x14;

    Config = XIicPs_LookupConfig(XIICPS_BASEADDRESS);
    if (NULL == Config) {
		return XST_FAILURE;
	}

    Status = XIicPs_CfgInitialize(&Iic, Config, Config->BaseAddress);
    if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    Status = XIicPs_SelfTest(&Iic);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    XIicPs_SetSClk(&Iic, IIC_SCLK_RATE);

    // enable clk0 and channels 0-3
    SendBuffer[0] = 0x04;
    SendBuffer[1] = 0x13;
    while (XIicPs_BusIsBusy(&Iic)) {
        /* NOP */
    };
    Status = XIicPs_MasterSendPolled(&Iic, SendBuffer, IIC_BUFFER_SIZE, SlaveAddr);
    if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    // setup 16 bit data width, delay by 0 and TDM mode
    SendBuffer[0] = 0x07;
    SendBuffer[1] = 0x53;
    while (XIicPs_BusIsBusy(&Iic)) {
        /* NOP */
    };
    Status = XIicPs_MasterSendPolled(&Iic, SendBuffer, IIC_BUFFER_SIZE, SlaveAddr);
    if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    // disable channel 4
    SendBuffer[0] = 0x0D;
    SendBuffer[1] = 0x00;
    while (XIicPs_BusIsBusy(&Iic)) {
        /* NOP */
    };
    Status = XIicPs_MasterSendPolled(&Iic, SendBuffer, IIC_BUFFER_SIZE, SlaveAddr);
    if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    // disable channel 5
    SendBuffer[0] = 0x0E;
    SendBuffer[1] = 0x00;
    while (XIicPs_BusIsBusy(&Iic)) {
        /* NOP */
    };
    Status = XIicPs_MasterSendPolled(&Iic, SendBuffer, IIC_BUFFER_SIZE, SlaveAddr);
    if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    // disable channel 6
    SendBuffer[0] = 0x0F;
    SendBuffer[1] = 0x00;
    while (XIicPs_BusIsBusy(&Iic)) {
        /* NOP */
    };
    Status = XIicPs_MasterSendPolled(&Iic, SendBuffer, IIC_BUFFER_SIZE, SlaveAddr);
    if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    // disable channel 7
    SendBuffer[0] = 0x10;
    SendBuffer[1] = 0x00;
    while (XIicPs_BusIsBusy(&Iic)) {
        /* NOP */
    };
    Status = XIicPs_MasterSendPolled(&Iic, SendBuffer, IIC_BUFFER_SIZE, SlaveAddr);
    if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    // check transmitted data 
    print("\r\n");
    for (int i=0; i<addressLookupNum; i++)
    {
        RecvAddrBuffer[0] = addressLookup[i];
        while (XIicPs_BusIsBusy(&Iic)) {
            /* NOP */
        };
        Status = XIicPs_MasterSendPolled(&Iic, RecvAddrBuffer, 1, SlaveAddr);
        if (Status != XST_SUCCESS) {
            return XST_FAILURE;
        }

        Status = XIicPs_MasterRecvPolled(&Iic, RecvBuffer, IIC_BUFFER_SIZE-1, SlaveAddr);
        if (Status != XST_SUCCESS) {
            return XST_FAILURE;
        }
        printf("Addr: 0x%x, data: 0x%x\r\n",addressLookup[i],  *RecvBuffer);
    }

    // restart chip with current configuration
    SendBuffer[0] = 0x12;
    SendBuffer[1] = 0x01;
    while (XIicPs_BusIsBusy(&Iic)) {
        /* NOP */
    };
    Status = XIicPs_MasterSendPolled(&Iic, SendBuffer, IIC_BUFFER_SIZE, SlaveAddr);
    if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}
    
    print("\r\n");
    printf("IIC set up complete.\r\n");
    print("\r\n");

    return XST_SUCCESS;
}

/*****************************************************************************/
/**
 * This function initializes external interrupt
 *
 * It setups interrupt from selected PL source, it is setup as regular priority
 * and it prepares GIC to be used for setup od other interrupt devices
 *
 * @return	status of operation
 *
 ******************************************************************************/
int init_intr()
{
    int Status;

    XScuGic *intc_instance_ptr = &intc;
    XScuGic_Config *intc_config;

    // check configuration
    intc_config = XScuGic_LookupConfig(XPAR_XSCUGIC_0_BASEADDR);
    if (NULL == intc_config)
    {
        return XST_FAILURE;
    }

    // initialize GIC
    Status = XScuGic_CfgInitialize(intc_instance_ptr, intc_config, intc_config->CpuBaseAddress);
    if (Status != XST_SUCCESS)
    {
        return XST_FAILURE;
    }

    // setup PL interrupt to be regular priority and rising edge
    XScuGic_SetPriorityTriggerType(intc_instance_ptr, interruptID_use, 0xA0, 0x3);

    // connect interrupt source to interrupt controller
    Status = XScuGic_Connect(intc_instance_ptr, interruptID_use, (Xil_ExceptionHandler)&IntrHandler, (void *)&intc);
    if (Status != XST_SUCCESS)
    {
        return XST_FAILURE;
    }

    // enable interrupt source
    XScuGic_Enable(intc_instance_ptr, interruptID_use);
    if (Status != XST_SUCCESS)
    {
        return XST_FAILURE;
    }

    // setup and enable exceptions
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XScuGic_InterruptHandler, intc_instance_ptr);
    Xil_ExceptionEnable();

    s32 res = XScuGic_SelfTest(intc_instance_ptr);
    printf("Interrupt enabled: %d\r\n", (int)res);

    return XST_SUCCESS;
}

/*****************************************************************************/
/**
 * This function periodic timer
 *
 * Timer is used to periodicaly check state of swithes and sound direciton.
 *
 *
 * @return	status of operation
 *
 ******************************************************************************/
int init_timer()
{
    int Status;
    XScuTimer_Config *ConfigPtr;
    XScuTimer * TimerInstancePtr = &TimerInstance;
    XScuGic *IntcInstancePtr = &intc;

    // lookup timer configuraion    
    ConfigPtr = XScuTimer_LookupConfig(XPAR_SCUTIMER_BASEADDR);

    // initialize timer
    Status = XScuTimer_CfgInitialize(TimerInstancePtr, ConfigPtr,
					ConfigPtr->BaseAddr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    Status = XScuTimer_SelfTest(TimerInstancePtr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    // connect and enable timer source to trigger an interrupt
    Status = XScuGic_Connect(IntcInstancePtr, XPAR_SCUTIMER_INTR,
				(Xil_ExceptionHandler)&TimerIntrHandler,
				(void *)TimerInstancePtr);
    
    XScuGic_Enable(IntcInstancePtr, XPAR_SCUTIMER_INTR);

    // setup timer reload values and start periodic timer
    XScuTimer_EnableAutoReload(TimerInstancePtr);

    XScuTimer_LoadTimer(TimerInstancePtr, TIMER_LOAD_VALUE);

    XScuTimer_Start(TimerInstancePtr);

    XScuTimer_EnableInterrupt(TimerInstancePtr);
    
    printf("Timer setup.\r\n");

    return XST_SUCCESS;
}

/*****************************************************************************/
/**
 * This function clears all buffers
 *
 * @return	none
 *
 ******************************************************************************/
void clear_buffer(void)
{
    // clear audio stream buffer
    for (int i=0; i<buff_p; i++)
    {
        buffer_p[i] = 0;
    }
    // clear array data buffers
    for (int i=0; i<buff_f; i++)
    {
        buffer1[i] = 0;
        buffer2[i] = 0;
    }

    flushing = 0;
    ind_f = 0;
    ind_p = 0; 

    printf("Cleared buffer\r\n");
}

/*****************************************************************************/
/**
 * This function writes to MIO LEDs according to input
 *
 * @param   index of led to be turned on
 *
 * @return	none
 *
 ******************************************************************************/
void write_LED(int led)
{
    switch (led) {
        case 0:
            XGpioPs_WritePin(&Gpiops, LED0, 0x1);
            XGpioPs_WritePin(&Gpiops, LED1, 0x0);
            XGpioPs_WritePin(&Gpiops, LED2, 0x0);
            XGpioPs_WritePin(&Gpiops, LED3, 0x0);
            XGpioPs_WritePin(&Gpiops, LED4, 0x0);
            XGpioPs_WritePin(&Gpiops, LED5, 0x0);
            XGpioPs_WritePin(&Gpiops, LED6, 0x0);
            XGpioPs_WritePin(&Gpiops, LED7, 0x0); 
            break;
        case 1:
            XGpioPs_WritePin(&Gpiops, LED0, 0x0);
            XGpioPs_WritePin(&Gpiops, LED1, 0x1);
            XGpioPs_WritePin(&Gpiops, LED2, 0x0);
            XGpioPs_WritePin(&Gpiops, LED3, 0x0);
            XGpioPs_WritePin(&Gpiops, LED4, 0x0);
            XGpioPs_WritePin(&Gpiops, LED5, 0x0);
            XGpioPs_WritePin(&Gpiops, LED6, 0x0);
            XGpioPs_WritePin(&Gpiops, LED7, 0x0); 
            break;
        case 2:
            XGpioPs_WritePin(&Gpiops, LED0, 0x0);
            XGpioPs_WritePin(&Gpiops, LED1, 0x0);
            XGpioPs_WritePin(&Gpiops, LED2, 0x1);
            XGpioPs_WritePin(&Gpiops, LED3, 0x0);
            XGpioPs_WritePin(&Gpiops, LED4, 0x0);
            XGpioPs_WritePin(&Gpiops, LED5, 0x0);
            XGpioPs_WritePin(&Gpiops, LED6, 0x0);
            XGpioPs_WritePin(&Gpiops, LED7, 0x0); 
            break;
        case 3:
            XGpioPs_WritePin(&Gpiops, LED0, 0x0);
            XGpioPs_WritePin(&Gpiops, LED1, 0x0);
            XGpioPs_WritePin(&Gpiops, LED2, 0x0);
            XGpioPs_WritePin(&Gpiops, LED3, 0x1);
            XGpioPs_WritePin(&Gpiops, LED4, 0x0);
            XGpioPs_WritePin(&Gpiops, LED5, 0x0);
            XGpioPs_WritePin(&Gpiops, LED6, 0x0);
            XGpioPs_WritePin(&Gpiops, LED7, 0x0); 
            break;
        case 4:
            XGpioPs_WritePin(&Gpiops, LED0, 0x0);
            XGpioPs_WritePin(&Gpiops, LED1, 0x0);
            XGpioPs_WritePin(&Gpiops, LED2, 0x0);
            XGpioPs_WritePin(&Gpiops, LED3, 0x0);
            XGpioPs_WritePin(&Gpiops, LED4, 0x1);
            XGpioPs_WritePin(&Gpiops, LED5, 0x0);
            XGpioPs_WritePin(&Gpiops, LED6, 0x0);
            XGpioPs_WritePin(&Gpiops, LED7, 0x0); 
            break;
        case 5:
            XGpioPs_WritePin(&Gpiops, LED0, 0x0);
            XGpioPs_WritePin(&Gpiops, LED1, 0x0);
            XGpioPs_WritePin(&Gpiops, LED2, 0x0);
            XGpioPs_WritePin(&Gpiops, LED3, 0x0);
            XGpioPs_WritePin(&Gpiops, LED4, 0x0);
            XGpioPs_WritePin(&Gpiops, LED5, 0x1);
            XGpioPs_WritePin(&Gpiops, LED6, 0x0);
            XGpioPs_WritePin(&Gpiops, LED7, 0x0); 
            break;
        case 6:
            XGpioPs_WritePin(&Gpiops, LED0, 0x0);
            XGpioPs_WritePin(&Gpiops, LED1, 0x0);
            XGpioPs_WritePin(&Gpiops, LED2, 0x0);
            XGpioPs_WritePin(&Gpiops, LED3, 0x0);
            XGpioPs_WritePin(&Gpiops, LED4, 0x0);
            XGpioPs_WritePin(&Gpiops, LED5, 0x0);
            XGpioPs_WritePin(&Gpiops, LED6, 0x1);
            XGpioPs_WritePin(&Gpiops, LED7, 0x0); 
            break;
        case 7:
            XGpioPs_WritePin(&Gpiops, LED0, 0x0);
            XGpioPs_WritePin(&Gpiops, LED1, 0x0);
            XGpioPs_WritePin(&Gpiops, LED2, 0x0);
            XGpioPs_WritePin(&Gpiops, LED3, 0x0);
            XGpioPs_WritePin(&Gpiops, LED4, 0x0);
            XGpioPs_WritePin(&Gpiops, LED5, 0x0);
            XGpioPs_WritePin(&Gpiops, LED6, 0x0);
            XGpioPs_WritePin(&Gpiops, LED7, 0x1); 
            break;      
        case 8:
            XGpioPs_WritePin(&Gpiops, LED0, 0x1);
            XGpioPs_WritePin(&Gpiops, LED1, 0x0);
            XGpioPs_WritePin(&Gpiops, LED2, 0x1);
            XGpioPs_WritePin(&Gpiops, LED3, 0x0);
            XGpioPs_WritePin(&Gpiops, LED4, 0x1);
            XGpioPs_WritePin(&Gpiops, LED5, 0x0);
            XGpioPs_WritePin(&Gpiops, LED6, 0x1);
            XGpioPs_WritePin(&Gpiops, LED7, 0x0); 
            break;      
        case 9:
            XGpioPs_WritePin(&Gpiops, LED0, 0x0);
            XGpioPs_WritePin(&Gpiops, LED1, 0x1);
            XGpioPs_WritePin(&Gpiops, LED2, 0x0);
            XGpioPs_WritePin(&Gpiops, LED3, 0x1);
            XGpioPs_WritePin(&Gpiops, LED4, 0x0);
            XGpioPs_WritePin(&Gpiops, LED5, 0x1);
            XGpioPs_WritePin(&Gpiops, LED6, 0x0);
            XGpioPs_WritePin(&Gpiops, LED7, 0x1); 
            break;      
        default:
            XGpioPs_WritePin(&Gpiops, LED0, 0x0);
            XGpioPs_WritePin(&Gpiops, LED1, 0x0);
            XGpioPs_WritePin(&Gpiops, LED2, 0x0);
            XGpioPs_WritePin(&Gpiops, LED3, 0x0);
            XGpioPs_WritePin(&Gpiops, LED4, 0x0);
            XGpioPs_WritePin(&Gpiops, LED5, 0x0);
            XGpioPs_WritePin(&Gpiops, LED6, 0x0);
            XGpioPs_WritePin(&Gpiops, LED7, 0x0);             
    } 
}

/*****************************************************************************/
/**
 * This function flushes buffer to UART
 *
 * @return	none
 *
 ******************************************************************************/
void flush_buffer(void)
{
    // flush array data buffer to uart
    for (int i=0; i<buff_f; i++)
    {   
        printf("0x%08x%08x\r\n", buffer2[i], buffer1[i]);
    }

    flushing = 0;
    ind_f = 0;
    printf("Flushed buffer\r\n");
}

/*****************************************************************************/
/**
 * This function checks state of switches and accordingly sets registers
 * for data aquisition
 * It also check if flushing of data is requested.
 *
 *
 * @return	none
 *
 ******************************************************************************/
void check_state(void)
{
    // read swichtes
    int state = XGpio_ReadReg(XGPIO8_AXI_BASEADDRESS, XGPIO_AXI_DATA_ADDR0);
    int sel = 0;
    int mic = 0;
    int flush = 0;
        
    // reads which microphone is used for data aquisition
    if (state & (1<<2))
    {
        sel = 4;
    }
    else
    {
        sel = ((state & (3<<3)) >> 3);        
    }

    // select used mic (FPGA or chip)
    mic = (state & (1<<5)) >> 5;

    mic_g = mic;

    // set flushing flag if needed
    flush = (state & (1<<7))>>7;

    flushing = flush;

    // setup correct microphone register
    if (sel == 0)
    { 
        if (mic == 0)
        {
            gpio_sel = XGPIO0_AXI_BASEADDRESS;
            write_LED(1); 
        }        
        else {
            gpio_sel = XGPIO3_AXI_BASEADDRESS;
            write_LED(0);
        }
        gpio_reg = XGPIO_AXI_DATA_ADDR0;
    }
    else if (sel == 1) 
    { 
        if (mic == 0)
        {
            gpio_sel = XGPIO0_AXI_BASEADDRESS;
            write_LED(3);
        }        
        else {
            gpio_sel = XGPIO3_AXI_BASEADDRESS;
            write_LED(6);
        }
        gpio_reg = XGPIO_AXI_DATA_ADDR1;
    }
    else if (sel == 2) 
    { 
        if (mic == 0)
        {
            gpio_sel = XGPIO1_AXI_BASEADDRESS;
            write_LED(7);
        }        
        else {
            gpio_sel = XGPIO4_AXI_BASEADDRESS;
            write_LED(2);
        }
        gpio_reg = XGPIO_AXI_DATA_ADDR0;
    }
    else if (sel == 3) 
    { 
        if (mic == 0)
        {
            gpio_sel = XGPIO1_AXI_BASEADDRESS;
            write_LED(5);
        }        
        else {
            gpio_sel = XGPIO4_AXI_BASEADDRESS;
            write_LED(4);
        }
        gpio_reg = XGPIO_AXI_DATA_ADDR1;
    }
    
    // set correct flush array register
    if (mic == 0)
    {
        gpio_w_sel = XGPIO2_AXI_BASEADDRESS;
    }        
    else {
        gpio_w_sel = XGPIO5_AXI_BASEADDRESS;
    }
    
}

/*****************************************************************************/
/**
 * Timer interrupt handler
 *
 * calls check state and check sound direction 
 *
 *
 * @return	none
 *
 ******************************************************************************/
static void TimerIntrHandler()
{
    static int cnt = 0;
    
    // call check state
    check_state();
        
    // get source position information
    if (flushing != 1)
    {    
        int x = XGpio_ReadReg(XGPIO7_AXI_BASEADDRESS, XGPIO_AXI_DATA_ADDR0);
        int y = XGpio_ReadReg(XGPIO7_AXI_BASEADDRESS, XGPIO_AXI_DATA_ADDR1);

        printf("x ind: %u, y ind: %u\r\n", x*100/640, y*100/480);
    }
    
    // toggle led to indicate working state
    if (cnt%2 == 0)
        XGpio_WriteReg(XGPIO8_AXI_BASEADDRESS, XGPIO_AXI_DATA_ADDR1, XGpio_ReadReg(XGPIO8_AXI_BASEADDRESS, XGPIO_AXI_DATA_ADDR1) | 0x00000001);
    else
        XGpio_WriteReg(XGPIO8_AXI_BASEADDRESS, XGPIO_AXI_DATA_ADDR1, XGpio_ReadReg(XGPIO8_AXI_BASEADDRESS, XGPIO_AXI_DATA_ADDR1) & 0xfffffffe);
    cnt++;
}

/*****************************************************************************/
/**
 * Interrupt handler
 *
 * captures data from PL and writes it to correct buffer
 *
 *
 * @return	none
 *
 ******************************************************************************/
static void IntrHandler()
{
    u32 in_buff = 0;
    u8 tmp_buff = 0;

    // if not flushing write data to array buffer, 
    // if flushing disabled to preserve data
    if (flushing != 1) 
    {
        if (ind_f < buff_f-1) {
            ind_f++;
        }
        else 
        {
            ind_f = 0;
        }
        buffer1[ind_f] = XGpio_ReadReg(gpio_w_sel, XGPIO_AXI_DATA_ADDR0);                
        buffer2[ind_f] = XGpio_ReadReg(gpio_w_sel, XGPIO_AXI_DATA_ADDR1);
    }
    
    // capture microphone data and modify it to be prepared for audio write opraration
    if (ind_p < buff_p-1)
    {
        ind_p++;
    }
    else {
        ind_p = 0;
    }
    in_buff = XGpio_ReadReg(gpio_sel, gpio_reg);
    if (mic_g == 0)
    {
        tmp_buff = (in_buff & 0x000007Fe) >> 3;
        buffer_p[ind_p] = tmp_buff;
    }  
    else {
        tmp_buff = (in_buff & 0x00003FC0) >> 6;
        buffer_p[ind_p] = tmp_buff;
    }      

    static int cnt = 0;
    if (cnt%2)
        XGpio_WriteReg(XGPIO8_AXI_BASEADDRESS, XGPIO_AXI_DATA_ADDR1, XGpio_ReadReg(XGPIO8_AXI_BASEADDRESS, XGPIO_AXI_DATA_ADDR1) | 0x00000002);
    else
        XGpio_WriteReg(XGPIO8_AXI_BASEADDRESS, XGPIO_AXI_DATA_ADDR1, XGpio_ReadReg(XGPIO8_AXI_BASEADDRESS, XGPIO_AXI_DATA_ADDR1) & 0xfffffffd);
    cnt++;

}