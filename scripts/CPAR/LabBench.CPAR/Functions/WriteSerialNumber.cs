using Inventors.ECP;
using Inventors.ECP.Communication;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Serialization;

namespace LabBench.CPAR.Functions
{
    public class WriteSerialNumber :
        DeviceFunction
    {
        public WriteSerialNumber() : base(0x05, requestLength: 2, responseLength: 0) { }

        public override FunctionDispatcher CreateDispatcher() => new FunctionDispatcher(0x05, () => new StopStimulation());

        public override bool Dispatch(dynamic listener) => listener.Accept(this);

        [XmlAttribute("serial-number")]
        public UInt16 SerialNumber
        {
            get
            {
                return Request.GetUInt16(0);
            }
            set
            {
                Request.InsertUInt16(0, value);
            }
        }

        public override string ToString() => "[0x15] Write Serial Number";
    }
}
