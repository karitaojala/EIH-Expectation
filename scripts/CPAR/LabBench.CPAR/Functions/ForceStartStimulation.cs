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
    public class ForceStartStimulation :
        DeviceFunction
    {
        public enum StopCriterion
        {
            STOP_CRITERION_ON_BUTTON_VAS = 0,
            STOP_CRITERION_ON_BUTTON
        }

        public ForceStartStimulation() :
            base(code: 0x0A, requestLength: 1, responseLength: 0)
        {
            Criterion = StopCriterion.STOP_CRITERION_ON_BUTTON_VAS;
        }

        public override FunctionDispatcher CreateDispatcher() => new FunctionDispatcher(0x0A, () => new ForceStartStimulation());

        public override bool Dispatch(dynamic listener) => listener.Accept(this);

        [Category("Stop Criterion")]
        [Description("Stop criterion for the stimulation")]
        [XmlAttribute("stop-criterion")]
        public StopCriterion Criterion
        {
            get => (StopCriterion)Request.GetByte(0);
            set => Request.InsertByte(0, (byte)value);
        }

        public override string ToString() => "[0x1A] Force Start Stimulation";
    }
}
