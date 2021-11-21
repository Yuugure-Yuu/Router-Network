--
--  Framework: Uwe R. Zimmer, Australia, 2015
--

with Ada.Strings.Bounded;           use Ada.Strings.Bounded;
with Ada.Real_Time;                 use Ada.Real_Time;
with Generic_Routers_Configuration;

generic
   with package Routers_Configuration is new Generic_Routers_Configuration (<>);

package Generic_Message_Structures is

   use Routers_Configuration;

   package Message_Strings is new Generic_Bounded_Length (Max => 80);
   use Message_Strings;

   subtype The_Core_Message is Bounded_String;

   type Messages_Client is record
      Destination : Router_Range;
      The_Message : The_Core_Message;
   end record;

   type Messages_Mailbox is record
      Sender      : Router_Range     := Router_Range'Invalid_Value;
      The_Message : The_Core_Message := Message_Strings.To_Bounded_String ("");
      Hop_Counter : Natural          := 0;
   end record;

   -- Leave anything above this line as it will be used by the testing framework
   -- to communicate with your router.

   --  Add one or multiple more messages formats here ..

   type Routing_Information is record
      -- array index is the destination
      -- store the shortest distance between the router and the destination
      Distance      : Natural;
      -- store the next step router to reach the destination
      Next_Router   : Router_Range;
      -- store the update time of this item
      Updating_Time : Time;
      -- store if the information is valid
      Validation    : Boolean := False;
      -- store if the router that id is the array index is shutdown
      Is_Shutdown   : Boolean := False;
   end record;

   type Routing_Informations is array (1 .. Router_Range'Last) of Routing_Information;
   type Messages_Router is record
      -- store router's id
      Router_Name : Router_Range;
      -- store router's RIP chart
      Information : Routing_Informations;
   end record;

   type Messages_Mail is record
      -- store the initial sender that receive the message
      Sender      : Router_Range := 1;
      -- store message send by the framework
      Core        : Messages_Client;
      -- store the final number of hops
      Hop_Counter : Natural      := 0;
   end record;

end Generic_Message_Structures;
