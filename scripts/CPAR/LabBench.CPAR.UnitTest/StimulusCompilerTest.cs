using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Text;
using LabBench.Interface.Stimuli;

namespace LabBench.CPAR.UnitTest
{
    [TestClass]
    public class StimulusCompilerTest
    {
        [TestMethod]
        public void CompilePulse()
        {
            var pulse = new Pulse()
            {
                Is = 50,
                Ts = 1,
                Tdelay = 0
            };
            var function = StimulusCompiler.Compile(pulse);

            Assert.AreEqual(expected: 1.0, actual: function.ProgramLength, 0.01);
        }
    }
}
