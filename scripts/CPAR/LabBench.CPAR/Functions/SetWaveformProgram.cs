using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.ComponentModel;
using System.Xml.Serialization;
using Inventors.ECP;
using Inventors.ECP.Communication;
using Inventors.ECP.Utility;

namespace LabBench.CPAR.Functions
{
    public class SetWaveformProgram :
        DeviceFunction
    {
        public const int MAX_NO_OF_INSTRUCTIONS = 20;
        public const byte FUNCTION_CODE = 0x02;
        public const double MAX_PRESSURE = 100;
        public const double UPDATE_RATE = 20;


        public SetWaveformProgram() : 
            base(FUNCTION_CODE, requestLength: 0, responseLength: 1)
        {
        }

        public override FunctionDispatcher CreateDispatcher() => new FunctionDispatcher(FUNCTION_CODE, () => new SetWaveformProgram());

        public override bool Dispatch(dynamic listener) => listener.Accept(this);

        [Category("Waveform Program")]
        [XmlElement("instruction")]
        public List<Instruction> Instructions { get; set; } = new List<Instruction>();

        [Category("Waveform Program")]
        [XmlAttribute("channel")]
        public byte Channel
        {
            get
            {
                return channel;
            }
            set
            {
                channel = (byte) (value > 1 ? 1 : value);
            }
        }

        [Category("Waveform Program")]
        [XmlAttribute("repeat")]
        public byte Repeat
        {
            get
            {
                return repeat;
            }
            set
            {
                repeat = (byte) (value > 0 ? value : 1);
            }
        }

        [Category("Waveform Program")]
        public byte ExpectedChecksum
        {
            get
            {
                return CRC8CCITT.Calculate(SerializeInstructions());
            }
        }

        [Category("Waveform Program")]
        public double ProgramLength
        {
            get
            {
                double retValue = 0;

                foreach (var instr in Instructions)
                {
                    retValue += instr.Steps;
                }

                return Repeat * retValue/UPDATE_RATE;
            }
        }

        [Category("Control")]
        public byte ActualChecksum
        {
            get
            {
                if (Response != null)
                {
                    return Response.GetByte(0);
                }
                else
                    return 0;
            }
        }

        public override void OnSend()
        {
            var encodedInstructions = SerializeInstructions();
            Request = new Packet(FUNCTION_CODE, encodedInstructions.Length + 2);
            Request.InsertByte(0, Channel);
            Request.InsertByte(1, Repeat);

            for (int n = 0; n < encodedInstructions.Length; ++n)
            {
                Request.InsertByte(n + 2, encodedInstructions[n]);
            }
        }

        private byte[] SerializeInstructions()
        {
            int noOfInstructions = NumberOfInstructions;
            int numBytes = noOfInstructions * Instruction.INSTRUCTIONS_LENGTH;
            int counter = 0;
            byte[] retValue = new byte[numBytes];

            for (int n = 0; n < noOfInstructions; ++n)
            {
                foreach (var b in Instructions[n].Encoding)
                {
                    retValue[counter] = b;
                    ++counter;
                }
            }

            return retValue;
        }

        [Category("Waveform Program")]
        public int NumberOfInstructions
        {
            get
            {
                return Instructions.Count > MAX_NO_OF_INSTRUCTIONS ?
                       MAX_NO_OF_INSTRUCTIONS :
                       Instructions.Count;
            }
        }

        public override string ToString() => "[0x12] Set Waveform Program";

        private byte channel = 0;
        private byte repeat = 1;
    }
}
