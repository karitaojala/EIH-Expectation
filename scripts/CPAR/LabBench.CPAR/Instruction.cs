using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Text;
using System.Xml.Serialization;

namespace LabBench.CPAR
{
    public class Instruction
    {
        public const int INSTRUCTIONS_LENGTH = 5;
        private const double UPDATE_RATE = 20;
        private const double MAX_PRESSURE = 100;

        public Instruction()
        {
            Encoding = new byte[INSTRUCTIONS_LENGTH];
            InstructionType = InstructionType.NOP;
            Argument = 0;
            Steps = 1;
        }

        public Instruction(InstructionType type)
        {
            Encoding = new byte[INSTRUCTIONS_LENGTH];
            InstructionType = type;
            Argument = 0;
            Steps = 1;
        }

        public static Instruction Increment(double delta, double time)
        {
            return new Instruction()
            {
                InstructionType = InstructionType.INC,
                Argument = (255 * (delta / MAX_PRESSURE)) / UPDATE_RATE,
                Steps = (ushort)(time * UPDATE_RATE)
            };
        }

        public static Instruction Decrement(double delta, double time)
        {
            return new Instruction()
            {
                InstructionType = InstructionType.DEC,
                Argument = (255 * (delta / MAX_PRESSURE)) / UPDATE_RATE,
                Steps = (ushort)(time * UPDATE_RATE)
            };
        }

        public static Instruction Step(double pressure, double time)
        {
            return new Instruction()
            {
                InstructionType = InstructionType.STEP,
                Argument = (255 * (pressure / MAX_PRESSURE)),
                Steps = (ushort)(time * UPDATE_RATE)
            };
        }

        [Category("Instruction")]
        [XmlAttribute("instruction-type")]
        public InstructionType InstructionType
        {
            get => (InstructionType)Encoding[0];
            set => Encoding[0] = (byte)value;
        }

        [Category("Instruction")]
        [XmlAttribute("argument")]
        public double Argument 
        {
            get => (((double)Encoding[1]) / 256) + Encoding[2];
            set
            {
                double truncated = value > 255 ? 255 : value < 0 ? 0 : value;
                Encoding[2] = (byte)Math.Truncate(truncated);
                Encoding[1] = (byte)Math.Truncate(256 * truncated);
            }
        }

        [Category("Instruction")]
        [XmlAttribute("steps")]
        public ushort Steps
        {
            get => (ushort)(Encoding[3] + Encoding[4] * 256);
            set
            {
                ushort steps = (ushort)(value == 0 ? 1 : value);
                Encoding[4] = (byte)(steps >> 8);
                Encoding[3] = (byte)(steps - (ushort)(Encoding[4] << 8));
            }
        }

        [Category("Encoding")]
        public byte[] Encoding { get; private set; }

        public override string ToString()
        {
            string retValue = "Instruction";

            switch (InstructionType)
            {
                case InstructionType.INC:
                    retValue = String.Format("{0} ({1:0.000}kPa/s, {2:0.00}s)",
                                              InstructionType.ToString(),
                                              MAX_PRESSURE * Argument / 255,
                                              ((double)Steps) / UPDATE_RATE);
                    break;
                case InstructionType.DEC:
                    retValue = String.Format("{0} (-{1:0.000}kPa/s, {2:0.00}s)",
                                              InstructionType.ToString(),
                                              MAX_PRESSURE * Argument / 255,
                                              ((double)Steps) / UPDATE_RATE);
                    break;
                case InstructionType.STEP:
                    retValue = String.Format("{0} ({1:0.000}kPa, {2:0.00}s)",
                                              InstructionType.ToString(),
                                              MAX_PRESSURE * Argument / 255,
                                              ((double)Steps) / UPDATE_RATE);
                    break;
                case InstructionType.NOP:
                    retValue = String.Format("{0} ({1:0.00}s)",
                                              InstructionType.ToString(),
                                              ((double)Steps) / UPDATE_RATE); ;
                    break;

            }

            return retValue;
        }
    }
}
