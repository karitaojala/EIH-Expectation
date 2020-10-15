using Inventors.ECP;
using Inventors.ECP.Communication;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace LabBench.CPAR.Messages
{
    public class EventMessage :
        DeviceMessage
    {
        public enum EventID
        {
            EVT_NO_EVENT = 0,
            EVT_STATUS_UPDATE,
            EVT_START_STIMULATION,
            EVT_STOP_STIMULATION,
            EVT_STOP_BUTTON_PRESSED,
            EVT_MAX_VAS_SCORED,
            EVT_VASMETER_DISCONNECTED,
            EVT_VASMETER_CONNECTED,
            EVT_EMERGENCY_ACTIVATED,
            EVT_EMERGENCY_DEACTIVATED,
            EVT_WAVEFORMS_COMPLETED,
            EVT_TIMELIMIT_EXCEEDED,
            EVT_COMM_WATCHDOG_TRIGGERED,
            EVT_CUFF01_OUT_OF_COMPLIANCE,
            EVT_CUFF02_OUT_OF_COMPLIANCE,
            EVT_SUPPLY_PRESSURE_LOW,
            EVT_COMPRESSOR_STARTED,
            EVT_COMPRESSOR_STOPPED,
            EVT_12V_POWER_OFF,
            EVT_12V_POWER_ON,
            EVT_AIR_LEAK
        }

        public static readonly byte CODE = 0x81;

        public override byte Code => CODE;

        public EventMessage() : base(CODE, 1) { }

        public EventMessage(Packet response) :
            base(response)
        {
            if (Packet.Length != 1)
            {
                throw new InvalidMessageException("A received EventMessage does not have a length of 1");
            }
        }

        public override MessageDispatcher CreateDispatcher() => new MessageDispatcher(CODE, (p) => new EventMessage(p));

        public override void Dispatch(dynamic listener) => listener.Accept(this);

        public EventID Event
        {
            get => (EventID) Packet.GetByte(0);
        }
    }
}
