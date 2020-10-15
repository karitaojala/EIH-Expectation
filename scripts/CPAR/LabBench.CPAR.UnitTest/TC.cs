using Inventors.ECP;
using LabBench.CPAR.Messages;
using LabBench.Interface;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;
using System.Threading;

namespace LabBench.CPAR.UnitTest
{
    public class TC : IDisposable
    {
        private static TC instance;
        private CPARDevice device;
        private Stopwatch watch;

        private TC(string port)
        {
            device = new CPARDevice()
            {
                Location = Location.Parse(port)
            };
            device.Open();
            watch = new Stopwatch();
        }

        private static TC Instance
        {
            get
            {
                if (instance is null)
                {
                    instance = new TC("COM18");
                }

                return instance;
            }
        }

        public static void Wait(AlgometerState state, int timeout)
        {
            Stopwatch timeoutWatch = new Stopwatch();
            Thread.Sleep(100);
            timeoutWatch.Restart();
            while (Device.State == state)
            {
                if (timeoutWatch.ElapsedMilliseconds > timeout)
                {
                    throw new InvalidOperationException("Timeout while waiting in state: " + state.ToString());
                }
            }
        }

        public static void Tic()
        {
            Instance.watch.Restart();
        }

        public static int Toc()
        {
            return (int) Instance.watch.ElapsedMilliseconds;
        }

        public static CPARDevice Device => Instance.device;

        #region IDisposable Support
        private bool disposedValue = false; // To detect redundant calls

        protected virtual void Dispose(bool disposing)
        {
            if (!disposedValue)
            {
                if (disposing)
                {
                    if (device is object)
                    {
                        device.Close();
                    }
                }
                disposedValue = true;
            }
        }

        public void Dispose()
        {
            Dispose(true);
        }
        #endregion
    }
}
