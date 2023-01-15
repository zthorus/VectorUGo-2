--
-- VectorUGo gane-console firmware that includes the ZTH1 CPU (modified version)

-- Note (2022-11-26): ADC for paddle not implemented yet, IRQ pins not connected
--                    Only one bit out of four (= ZTH1v output lines) is used but the 4 bits are connected to the Arduino port

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity vectorugo is 
  port(
        clk_in    : in std_logic;                    -- 10-MHz master clock
		  joyst     : in std_logic_vector(4 downto 0);    -- joystick imput (4 directions + fire)
		  -- paddl     : in std_logic_vector(7 downto 0);    -- paddle input (from ADC)
		  audio     : out std_logic_vector(3 downto 0);   -- audio output
        sdi_x     : out std_logic;                     -- DAC x data
		  sdi_y     : out std_logic;                     -- DAC y data   
		  z_axis    : out std_logic;                     -- scope z axis    
		  ncs_xy    : out std_logic;
		  nladc_xy  : out std_logic;
		  clk_xy    : out std_logic
		  -- irq       : in std_logic_vector(1 downto 0)
		);
end vectorugo;

architecture behavior of vectorugo is

  -- game controllers to ZTH1 signal
  signal gc : std_logic_vector(12 downto 0);
  
  -- ZTH1 to RAM signals
  signal ram_a_zbus    : std_logic_vector(11 downto 0);
  signal ram_h_rd_zbus : std_logic_vector(7 downto 0);
  signal ram_l_rd_zbus : std_logic_vector(7 downto 0);
  signal ram_h_wr_zbus : std_logic_vector(7 downto 0);
  signal ram_l_wr_zbus : std_logic_vector(7 downto 0);
  signal ram_h_zwren   : std_logic;
  signal ram_l_zwren   : std_logic;
  signal ram_h_zrden   : std_logic;
  signal ram_l_zrden   : std_logic;
  
  -- ZTH1 to ROM signals
  signal rom_a_bus : std_logic_vector(12 downto 0);
  signal rom_d_bus : std_logic_vector(15 downto 0);
  signal rom_rden  : std_logic;
 
  -- RAM to vector-display signals
  signal ram_a_vbus    : std_logic_vector(11 downto 0);
  signal ram_h_rd_vbus : std_logic_vector(7 downto 0);
  signal ram_l_rd_vbus : std_logic_vector(7 downto 0);
  signal ram_rd_vbus   : std_logic_vector(15 downto 0);
  
  -- vector-display to DAC driver signals
  signal x_val : std_logic_vector(7 downto 0);
  signal y_val : std_logic_vector(7 downto 0);
  signal trzx  : std_logic_vector(3 downto 0);
  signal trzy  : std_logic_vector(3 downto 0);
  signal dv    : std_logic;
  signal dack  : std_logic;

  -- clock signals
  signal clk_1   : std_logic;  -- 2-MHz clock for the DAC drivers
  signal clk_2   : std_logic;  -- 167-kHz clock for the vector display device
  signal mem_clk : std_logic;  -- inverted 10-MHz clock for the RAM and ROM
  
  
  signal vcc  : std_logic := '1';
  signal vcc2 : std_logic_vector(1 downto 0) := "11";
  signal gnd  : std_logic := '0';
  signal gnd8 : std_logic_vector(7 downto 0) := "00000000";

begin
  -- clock for DAC driver set to 2 Mhz (other components use 10-Mhz clock)
  clks  : entity work.clocks port map(clk_in,clk_1,clk_2);
	
  cpu : entity work.zth1v_cpu port map(clk_in,ram_a_zbus,ram_h_rd_zbus,ram_l_rd_zbus,ram_h_wr_zbus,ram_l_wr_zbus,rom_a_bus,rom_d_bus,gc,audio,vcc2,
	                                   ram_h_zwren,ram_l_zwren,ram_h_zrden,ram_l_zrden,rom_rden);
												  
  data_ram_h : entity work.ram_h port map(ram_a_zbus,ram_a_vbus,mem_clk,ram_h_wr_zbus,gnd8,ram_h_zrden,vcc,ram_h_zwren,gnd,ram_h_rd_zbus,ram_h_rd_vbus);
  
  data_ram_l : entity work.ram_l port map(ram_a_zbus,ram_a_vbus,mem_clk,ram_l_wr_zbus,gnd8,ram_l_zrden,vcc,ram_l_zwren,gnd,ram_l_rd_zbus,ram_l_rd_vbus);

  instruction_rom : entity work.rom port map(rom_a_bus,mem_clk,rom_rden,rom_d_bus);
  
  disp  : entity work.vector_display port map(clk_2,ram_a_vbus,ram_rd_vbus,dv,x_val,y_val,z_axis,trzx,trzy,dack);
  
  dac_x : entity work.mcp4821_drv port map(clk_1,x_val,dv,dack,trzx,sdi_x,ncs_xy,nladc_xy,clk_xy);
  dac_y : entity work.mcp4821_drv port map(clk_1,y_val,dv,open,trzy,sdi_y,open,open,open);
  
  mem_clk <= not clk_in;
  gc <= gnd8 & joyst;
  ram_rd_vbus <= ram_h_rd_vbus & ram_l_rd_vbus;
  
end behavior;