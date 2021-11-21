--

--  Framework: Uwe R. Zimmer, Australia, 2019
--

with Exceptions;                         use Exceptions;
with Ada.Real_Time;                      use Ada.Real_Time;
package body Generic_Router is

   task body Router_Task is

      Connected_Routers  : Ids_To_Links;
      -- store the message for inner-router communication
      Pre_Message_Router : Messages_Router;
      -- store the message sent by framework when the router is destination
      Pre_Mail           : Messages_Mail;
      -- check if need to terminate the router
      Termination        : Boolean           := False;
      -- duration for waiting for response
      RESPONSE_TIME      : constant Duration := 0.000001;
   begin
      accept Configure (Links : Ids_To_Links) do
         Connected_Routers := Links;
      end Configure;

      declare
         Port_List : constant Connected_Router_Ports := To_Router_Ports (Task_Id, Connected_Routers);
      begin
         -- Setup time is proportional to the diameter of the network with very short code by implementing RIP algorithm.
         -- Could have different results in different computers when drop-out routers because there's too many task entities.
         -- So better only drop one router.
         -- references:
         -- RIP algorithm: https://en.wikipedia.org/wiki/Routing_Information_Protocol
         -- piazza https://piazza.com/class/kpqpet3jgx46xp?cid=827 https://piazza.com/class/kpqpet3jgx46xp?cid=859
         Pre_Message_Router.Router_Name := Task_Id;

         for Port of Port_List loop
            Pre_Message_Router.Information (Port.Id).Next_Router   := Port.Id;
            Pre_Message_Router.Information (Port.Id).Distance      := 1;
            Pre_Message_Router.Information (Port.Id).Updating_Time := Clock;
            Pre_Message_Router.Information (Port.Id).Validation    := True;
         end loop;
         Pre_Message_Router.Information (Task_Id).Next_Router   := Task_Id;
         Pre_Message_Router.Information (Task_Id).Distance      := 0;
         Pre_Message_Router.Information (Task_Id).Updating_Time := Clock;
         Pre_Message_Router.Information (Task_Id).Validation    := True;

         declare
            -- task for inner-router communication
            task Broadcaster is
            end Broadcaster;
            task body Broadcaster is
            begin
               loop
                  for Next_Router in Port_List'Range loop
                     if not Pre_Message_Router.Information (Router_Range (Next_Router)).Is_Shutdown
                     then
                        Sending_3 :
                        begin
                           select
                              Port_List (Next_Router).Link.all.Send (Pre_Message_Router);
                           or
                              delay RESPONSE_TIME;
                           end select;
                        exception
                           when Tasking_Error =>
                              Pre_Message_Router.Information (Router_Range (Next_Router)).Is_Shutdown := True;
                              Pre_Message_Router.Information (Router_Range (Next_Router)).Validation  := False;
                              for i in 1 .. Router_Range'Last loop
                                 if Pre_Message_Router.Information (i).Validation = True
                                   and then Pre_Message_Router.Information (i).Next_Router = Router_Range (Next_Router)
                                 then
                                    Pre_Message_Router.Information (i).Validation := False;
                                 end if;
                              end loop;
                        end Sending_3;
                        delay 0.0;
                        -- because our computer sometimes can't handle with so many tasks
                     end if;
                  end loop;
               end loop;
            end Broadcaster;

         begin
            while not Termination loop
               select
                  -- update information of rip chart according to three principles
                  -- 1. valid one in if not valid
                  -- 2. choose the shorter if next_jump if different
                  -- 3. choose the newer if next_jump if the same even if it's longer(because of drop-out)
                  accept Send (Message : in Messages_Router) do
                     begin
                        for i in 1 .. Router_Range'Last loop
                           if Message.Information (i).Is_Shutdown = True and then Pre_Message_Router.Information (i).Is_Shutdown = False
                           then
                              Pre_Message_Router.Information (i).Is_Shutdown := True;
                              Pre_Message_Router.Information (i).Validation  := False;
                              for i in 1 .. Router_Range'Last loop
                                 if Pre_Message_Router.Information (i).Validation = True
                                   and then Pre_Message_Router.Information (Pre_Message_Router.Information (i).Next_Router).Is_Shutdown = True
                                 then
                                    Pre_Message_Router.Information (i).Validation := False;
                                 end if;
                              end loop;
                           end if;
                        end loop;
                        for i in 1 .. Router_Range'Last loop
                           if Message.Information (i).Validation = True
                             and then Pre_Message_Router.Information (i).Is_Shutdown = False
                             and then Pre_Message_Router.Information (Message.Information (i).Next_Router).Is_Shutdown = False
                           then
                              if Pre_Message_Router.Information (i).Validation = False
                                or else (Pre_Message_Router.Information (i).Next_Router /= Message.Router_Name
                                         and then Pre_Message_Router.Information (i).Distance > Message.Information (i).Distance + 1)
                                or else (Pre_Message_Router.Information (i).Next_Router = Message.Router_Name
                                         and then Pre_Message_Router.Information (i).Updating_Time < Message.Information (i).Updating_Time)
                              then
                                 Pre_Message_Router.Information (i).Next_Router   := Message.Router_Name;
                                 Pre_Message_Router.Information (i).Distance      := Message.Information (i).Distance + 1;
                                 Pre_Message_Router.Information (i).Updating_Time := Clock;
                                 Pre_Message_Router.Information (i).Validation    := True;
                              end if;
                           end if;
                        end loop;
                     end;
                  end Send;

               or
                  -- accept mail from framework and mail it if needed, preserve it if not
                  accept Send_Mail (Mail : in Messages_Mail) do
                     declare
                        Mail_Copy : Messages_Mail;
                     begin
                        if Mail.Core.Destination = Task_Id
                        then
                           Pre_Mail := Mail;
                        else
                           Mail_Copy.Sender      := Mail.Sender;
                           Mail_Copy.Core        := Mail.Core;
                           Mail_Copy.Hop_Counter := Mail.Hop_Counter + 1;
                           for Port of Port_List loop
                              if Port.Id = Pre_Message_Router.Information (Mail.Core.Destination).Next_Router
                                and then Pre_Message_Router.Information (Router_Range (Port.Id)).Is_Shutdown = False
                              then
                                 Sending_1 :
                                 begin
                                    Port.Link.all.Send_Mail (Mail_Copy);
                                 exception
                                    when Tasking_Error =>
                                       Pre_Message_Router.Information (Router_Range (Port.Id)).Is_Shutdown := True;
                                       Pre_Message_Router.Information (Router_Range (Port.Id)).Validation  := False;
                                       for i in 1 .. Router_Range'Last loop
                                          if Pre_Message_Router.Information (i).Validation = True
                                            and then Pre_Message_Router.Information (i).Next_Router = Port.Id
                                          then
                                             Pre_Message_Router.Information (i).Validation := False;
                                          end if;
                                       end loop;
                                       for Port_2 of Port_List loop
                                          if Pre_Message_Router.Information (Port_2.Id).Is_Shutdown = False
                                          then
                                             select
                                                Port_2.Link.all.Send_Mail (Mail_Copy);
                                                exit;
                                             or
                                                delay RESPONSE_TIME;
                                             end select;
                                          end if;
                                       end loop;
                                 end Sending_1;
                                 exit;
                              end if;
                           end loop;
                        end if;
                     end;
                  end Send_Mail;

               or
                  -- accept mail from other routers and mail it if needed, preserve it if not
                  accept Send_Message (Message : in Messages_Client) do
                     declare
                        Mail : Messages_Mail;
                     begin
                        if Message.Destination = Task_Id
                        then
                           Pre_Mail.Core        := Message;
                           Pre_Mail.Sender      := Task_Id;
                           Pre_Mail.Hop_Counter := 0;
                        else
                           Mail.Core        := Message;
                           Mail.Sender      := Task_Id;
                           Mail.Hop_Counter := 1;
                           for Port of Port_List loop
                              if Port.Id = Pre_Message_Router.Information (Message.Destination).Next_Router
                                and then Pre_Message_Router.Information (Router_Range (Port.Id)).Is_Shutdown = False
                              then
                                 Sending_2 :
                                 begin
                                    Port.Link.all.Send_Mail (Mail);
                                 exception
                                    when Tasking_Error =>
                                       Pre_Message_Router.Information (Router_Range (Port.Id)).Is_Shutdown := True;
                                       Pre_Message_Router.Information (Router_Range (Port.Id)).Validation  := False;
                                       for i in 1 .. Router_Range'Last loop
                                          if Pre_Message_Router.Information (i).Validation = True
                                            and then Pre_Message_Router.Information (i).Next_Router = Port.Id
                                          then
                                             Pre_Message_Router.Information (i).Validation := False;
                                          end if;
                                       end loop;
                                       for Port_2 of Port_List loop
                                          if Pre_Message_Router.Information (Port_2.Id).Is_Shutdown = False
                                          then
                                             select
                                                Port_2.Link.all.Send_Mail (Mail);
                                                exit;
                                             or
                                                delay RESPONSE_TIME;
                                             end select;
                                          end if;
                                       end loop;
                                 end Sending_2;
                                 exit;
                              end if;
                           end loop;

                        end if;
                     end;
                  end Send_Message;

               or
                  accept Receive_Message (Message : out Messages_Mailbox) do
                     begin
                        Message.Sender      := Pre_Mail.Sender;
                        Message.The_Message := Pre_Mail.Core.The_Message;
                        Message.Hop_Counter := Pre_Mail.Hop_Counter;
                     end;
                  end Receive_Message;

               or
                  -- when receiving shutdown, router have to die immediately without sending any message
                  accept Shutdown do
                     begin
                        abort Broadcaster;
                        Termination := True;
                     end;
                  end Shutdown;
               end select;
            end loop;
         end;
      end;

   exception
      when Exception_Id : others => Show_Exception (Exception_Id);
   end Router_Task;

end Generic_Router;
