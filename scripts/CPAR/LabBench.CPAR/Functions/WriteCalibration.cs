using Inventors.ECP;
using Inventors.ECP.Communication;
using Inventors.ECP.Utility;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Serialization;

namespace LabBench.CPAR.Functions
{
    public class WriteCalibration :
        DeviceFunction
    {
        public static byte FUNCTION_CODE = 0x06;
        private static byte CALIBRATION_RECORD_SIZE = 10;
        private static byte VALID_MARKER = 0xC9;

        public WriteCalibration() : 
            base(FUNCTION_CODE, requestLength: (byte) (CALIBRATION_RECORD_SIZE + 1), responseLength: 0)
        {
            Calibrator = CalibratorID.ID_VAS_SCORE_CALIBRATOR;
            Request.InsertByte(1, VALID_MARKER);
            A = 1;
            B = 0;
        }

        public override FunctionDispatcher CreateDispatcher() => new FunctionDispatcher(FUNCTION_CODE, () => new StopStimulation());

        public override bool Dispatch(dynamic listener) => listener.Accept(this);

        [XmlAttribute("calibrator")]
        public CalibratorID Calibrator
        {
            get => (CalibratorID)Request.GetByte(0);
            set => Request.InsertByte(0, (byte)value);
        }

        [XmlAttribute("A")]
        public double A
        {
            get
            {
                return ((double)Request.GetInt32(2)) / 256;
            }
            set
            {
                Request.InsertInt32(2, (Int32)Math.Truncate(value * 256));
                CreateChecksum();
            }
        }

        [XmlAttribute("B")]
        public double B
        {
            get
            {
                return ((double)Request.GetInt32(6)) / 256;
            }
            set
            {
                Request.InsertInt32(6, (Int32)Math.Truncate(value * 256));
                CreateChecksum();
            }
        }

        public byte Checksum
        {
            get
            {
                return Request.GetByte(CALIBRATION_RECORD_SIZE);
            }
        }

        private void CreateChecksum()
        {
            byte checksum = 0;

            for (int n = 1; n < CALIBRATION_RECORD_SIZE; ++n)
            {
                checksum = CRC8CCITT.Update(checksum, Request.GetByte(n));
            }

            Request.InsertByte(CALIBRATION_RECORD_SIZE, checksum);
        }

        public override string ToString() => "[0x16] Write Calibration Record";
    }
}
