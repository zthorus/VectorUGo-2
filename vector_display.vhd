
-- Vector-display device, X and Y outputs sent to DACs

-- The table of vectors to be drawn is stored in a 16-bit RAM 
-- With the following structure:

-- address | hi byte  | lo byte
-- 0       | offs_x   | offs_y
-- 1       | zpt_x    | zpt_y
-- 1       |         Nvec     
-- 2       | x_v1     | y_v1
-- 3       | l_v1 z_v1| 
-- 4       | x_v2     | y_v2
-- 5       | l_v2 z_v2| 
-- ...

-- The frequency clock of the vector-display device is 167 kHz. With a standard vector length = 19, it takes 22 clock cycles 
-- to display a vector. This means up to 7500 vecs/s can be displayed. For a 25-Hz frame rate, 300 vecs/frame can be displayed.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity vector_display is
  port (
    clk       : in std_logic;                      -- 500-kHz clock driving the system
	 addr      : out std_logic_vector(11 downto 0); -- address of vector in table (memory)
	 data      : in std_logic_vector(15 downto 0);  -- data on vector from memory
	 d_valid   : out std_logic;                     -- X and Y signals OK for DACs
	 x         : out std_logic_vector(7 downto 0);  -- X signal
	 y         : out std_logic_vector(7 downto 0);  -- Y signal
	 z         : out std_logic;                     -- Z signal (intensity)
	 offs_x    : out std_logic_vector(3 downto 0);  -- x offset (DAC trimming)
	 offs_y    : out std_logic_vector(3 downto 0);  -- y offset (DAC trimming)
	 dac_ack   : in std_logic                       -- acknowledge from DAC driver
  );
end vector_display;


architecture behavior of vector_display is
begin
  process(clk)
    variable zpt_x  : integer range 0 to 255 := 157; -- value of zero-point for x
	 variable zpt_y  : integer range 0 to 255 := 157; -- value of zero-point for y
	 variable xv     : integer range -128 to 127;     -- x of vector
	 variable yv     : integer range -128 to 127;     -- y of vector
    variable c      : integer;                       -- counter (RAM access)
	 variable nvec   : integer;                       -- number of vectors to be drawn
    variable nv     : integer;                       -- number of already drawn vectors
	 variable state  : integer := 0;                  -- state of the FSM
	 variable l      : integer;                       -- vector length (in on/off cycles)
	 variable v_a    : std_logic_vector(11 downto 0); -- address of vector
	 variable incr   : std_logic;                     -- true if xx or yy need to be incremented
  begin
    if rising_edge(clk) then
	   case state is
		
		  -- prepare to load offs_x and offs_y (= lowest 4 bits of values sent to DACs)
	     when 0 => v_a := "000000000000";
						state := 1; 
		
		  -- read offsets from RAM, send them (as 4-bit nibbles) to the DAC drivers 
		  when 1 => offs_x <= data(11 downto 8);
		            offs_y <= data(3 downto 0);
		            v_a := "000000000001";
						state := 2; 
						
		  -- read zero points from RAM
		  when 2 => zpt_x := to_integer(unsigned(data(15 downto 8)));
		            zpt_y := to_integer(unsigned(data(7 downto 0)));
						v_a := "000000000010";
						state := 3;
		  
		  -- read number of vectors from RAM
	     when 3 => nvec := to_integer(unsigned(data(15 downto 0)));
		            nv := 1;
		            v_a := "000000000011";
						state := 4;
						
		  -- read x and y of vector
		  when 4 => xv := to_integer(signed(data(15 downto 8)));
		            yv := to_integer(signed(data(7 downto 0)));
						v_a := v_a + 1;
						state := 5;
		  
		  -- read l of vector (bits 7 to 1 of hi byte read), z (bit 0 of hi byte read), then send vector data and validate them for the DACs
		  when 5 => l := to_integer(unsigned(data(15 downto 9)));
		  				x <= std_logic_vector(to_unsigned(zpt_x - xv,8));
		  				y <= std_logic_vector(to_unsigned(zpt_y - yv,8));
						z <= not data(8); -- z = 1 => spot off 
						d_valid <= '1'; 
						v_a := v_a + 1;
						state := 6;
						c := 0;
						
	     -- draw vector (wait until drawn)					
		  when 6 => c := c + 1;
		            --if (ack = '1') then
		            --  d_valid <= '0';
						-- end if;
		            if (c > l) then
						  d_valid <= '0';
						  nv := nv + 1 ;
						  if (nv > nvec) then
							 -- all vectors drawn, go for a new frame 
							 state := 0;
						  else
							 -- otherwise, prepare to read next vector
							 state := 4;
						  end if;
						end if;
			
		  when others => state := 0;
		 end case;
	  end if;
	  addr <= v_a;
   end process;
 end behavior;