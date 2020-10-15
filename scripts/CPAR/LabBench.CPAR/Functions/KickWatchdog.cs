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
    public class KickWatchdog :
        DeviceFunction
    {
        public KickWatchdog() : base(0x08, requestLength: 0, responseLength: 4) { }

        public override FunctionDispatcher CreateDispatcher() => 
            new FunctionDispatcher(0x08, () => new KickWatchdog());

        public override bool Dispatch(dynamic listener) => listener.Accept(this);

        [Category("Watchdog")]
        [Description("Number of times the watchdog has been kicked")]
        public UInt32 Counter => Response.GetUInt32(0);

        public override string ToString() => "[0x02] Kick Watchdog";
    }
}
