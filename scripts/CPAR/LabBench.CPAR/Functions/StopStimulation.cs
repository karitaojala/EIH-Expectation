using Inventors.ECP;
using Inventors.ECP.Communication;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace LabBench.CPAR.Functions
{
    public class StopStimulation : 
        DeviceFunction
    {
        public StopStimulation() : base(0x04, requestLength: 0, responseLength: 0) { }

        public override FunctionDispatcher CreateDispatcher() => new FunctionDispatcher(0x04, () => new StopStimulation());

        public override bool Dispatch(dynamic listener) => listener.Accept(this);

        public override string ToString() => "[0x04] Stop Stimulation";
    }
}
