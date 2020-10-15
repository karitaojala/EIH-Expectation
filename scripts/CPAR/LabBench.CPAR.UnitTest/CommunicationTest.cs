using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Text;

namespace LabBench.CPAR.UnitTest
{
    [TestClass]
    public class CommunicationTest
    {
        [TestMethod]
        public void KickWatchdog()
        {
            var device = TC.Device;
            TC.Tic();
            var kicks = device.Ping();
            Console.WriteLine("Initial ping execution time: {0}ms", TC.Toc());
            Console.WriteLine("Current watchdogs kicks: {0}", kicks);
            TC.Tic();
            Assert.AreEqual(expected: kicks + 1, actual: device.Ping());
            Console.WriteLine("Ping execution time: {0}ms", TC.Toc());
            TC.Tic();
            Assert.AreEqual(expected: kicks + 2, actual: device.Ping());
            Console.WriteLine("Ping execution time: {0}ms", TC.Toc());
            TC.Tic();
            Assert.AreEqual(expected: kicks + 3, actual: device.Ping());
            Console.WriteLine("Ping execution time: {0}ms", TC.Toc());
            TC.Tic();
            Assert.AreEqual(expected: kicks + 4, actual: device.Ping());
            Console.WriteLine("Ping execution time: {0}ms", TC.Toc());
            TC.Tic();
            Assert.AreEqual(expected: kicks + 5, actual: device.Ping());
            Console.WriteLine("Ping execution time: {0}ms", TC.Toc());
        }

        [TestMethod]
        public void DeviceIdentification()
        {
            var device = TC.Device;
            var devId = device.CreateIdentificationFunction() as LabBench.CPAR.Functions.DeviceIdentification;
            Console.WriteLine("typeof(devId): {0}", device.CreateIdentificationFunction().GetType().ToString());
            Assert.IsTrue(devId is object);

            TC.Tic();
            device.Execute(devId);
            Console.WriteLine("Device identification execution time: {0}ms", TC.Toc());
            Console.WriteLine("Identify: {0}", devId.Identity);
            Console.WriteLine("MajorRevision: {0}", devId.MajorRevision);
            Console.WriteLine("EngineeringRevision: {0}", devId.EngineeringRevision);
            Console.WriteLine("Checksum: {0}", devId.Checksum);
            Console.WriteLine("Serial: {0}", devId.SerialNumber);
        }
    }
}
