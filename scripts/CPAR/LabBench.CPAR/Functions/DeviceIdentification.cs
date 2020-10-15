using Inventors.ECP;
using Inventors.ECP.Communication;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace LabBench.CPAR.Functions
{
    public class DeviceIdentification :
       DeviceFunction
    {
        public DeviceIdentification() : base(0x01, requestLength: 0, responseLength: 6) { }

        public override FunctionDispatcher CreateDispatcher() =>
            new FunctionDispatcher(0x01, () => new DeviceIdentification());

        public override bool Dispatch(dynamic listener) => listener.Accept(this);

        [Category("Device")]
        [Description("The type of device that is connected")]
        public byte Identity => Response.GetByte(0);

        [Category("Revision")]
        [Description("Major Version")]
        public byte MajorRevision => Response.GetByte(1);

        [Category("Revision")]
        [Description("Engineering Version")]
        public byte EngineeringRevision => Response.GetByte(2);

        [Category("Device")]
        [Description("The serial number of device that is connected")]
        public UInt16 SerialNumber => Response.GetUInt16(4);

        [Category("Device")]
        [Description("The serial number of device that is connected")]
        public byte Checksum => Response.GetByte(3);

        public override string ToString() => "[0x01] Device Identification";
    }
}
