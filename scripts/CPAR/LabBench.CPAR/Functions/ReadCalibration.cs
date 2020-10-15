using Inventors.ECP;
using Inventors.ECP.Communication;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Serialization;

namespace LabBench.CPAR.Functions
{
    public class ReadCalibration : 
        DeviceFunction
    {
        public static byte FUNCTION_CODE = 0x07;
        private static byte CALIBRATION_RECORD_SIZE = 10;
        private static byte VALID_MARKER = 0xC9;

        public ReadCalibration() : 
            base(FUNCTION_CODE, requestLength: 1, responseLength: CALIBRATION_RECORD_SIZE)
        {
            Calibrator = CalibratorID.ID_VAS_SCORE_CALIBRATOR;
        }

        public override FunctionDispatcher CreateDispatcher() => new FunctionDispatcher(FUNCTION_CODE, () => new ReadCalibration());

        public override bool Dispatch(dynamic listener) => listener.Accept(this);

        [Category("Calibrator")]
        [XmlAttribute("calibrator")]
        public CalibratorID Calibrator
        {
            get
            {
                return (CalibratorID)Request.GetByte(0);
            }
            set
            {
                Request.InsertByte(0, (byte)value);
            }
        }

        [Category("Calibration Record")]
        public bool ValidMarker
        {
            get
            {
                if (Response != null)
                    return Response.GetByte(0) == VALID_MARKER;
                else
                    return false;
            }
        }

        [Category("Calibration Record")]
        public double A
        {
            get
            {
                if (Response != null)
                    return ((double)Response.GetInt32(1)) / 256;
                else
                    return 0;
            }
        }

        [Category("Calibration Record")]
        public double B
        {
            get
            {
                if (Response != null)
                    return ((double)Response.GetInt32(5)) / 256;
                else
                    return 0;
            }
        }

        [Category("Calibration Record")]
        public byte Checksum
        {
            get
            {
                if (Response != null)
                    return Response.GetByte(CALIBRATION_RECORD_SIZE - 1);
                else
                    return 0;
            }
        }

        public override string ToString() => "[0x17] Read Calibration Record";
    }
}
