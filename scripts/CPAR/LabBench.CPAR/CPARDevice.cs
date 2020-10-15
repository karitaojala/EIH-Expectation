using System;
using System.Collections.Generic;
using System.Text;
using LabBench.CPAR.Functions;
using LabBench.CPAR.Messages;
using Inventors.ECP;
using Inventors.ECP.Communication;
using Inventors.ECP.Functions;
using Inventors.Logging;
using LabBench.Interface;
using System.Threading;
using System.Linq;

namespace LabBench.CPAR
{
    public class CPARDevice :
        Device,
        IPressureAlgometer
    {
        #region Device implementation
        private bool _ping = false;

        public bool PingEnabled
        {
            get { lock (LockObject) { return _ping; } }
            set => SetPropertyLocked(ref _ping ,value); 
        }

        bool IPressureAlgometer.Ping
        {
            get => PingEnabled;
            set => PingEnabled = value;
        }

        public CPARDevice() :
            base(new SerialPortLayer())
        {
            BaudRate = 38400;

            FunctionList.Add(new LabBench.CPAR.Functions.DeviceIdentification());

            FunctionList.Add(new SetWaveformProgram());
            FunctionList.Add(new StartStimulation());
            FunctionList.Add(new StopStimulation());
            FunctionList.Add(new WriteSerialNumber());
            FunctionList.Add(new WriteCalibration());
            FunctionList.Add(new ReadCalibration());
            FunctionList.Add(new KickWatchdog());
            FunctionList.Add(new ForceStartStimulation());


            Master.Add(new StatusMessage());
            Master.Add(new EventMessage());

            timer = new Timer(OnTimer, this, 500, 500);
            _channels.Add(new PressureChannel(1, this));
            _channels.Add(new PressureChannel(2, this));
        }

        public override DeviceFunction CreateIdentificationFunction()
        {
            return new LabBench.CPAR.Functions.DeviceIdentification();
        }

        public override bool IsCompatible(DeviceFunction function)
        {
            bool retValue = false;

            if (function is null)
            {
                throw new ArgumentNullException(nameof(function));
            }

            if (function is LabBench.CPAR.Functions.DeviceIdentification identification)
            {
                retValue = (identification.Identity == 1);
            }


            return retValue;
        }

        public void Accept(EventMessage msg)
        {
            Log.Debug(msg.Code.ToString());
        }

        public void Accept(StatusMessage msg)
        {
            var oldState = State;
            State = GetState(msg); 
            StopCondition = (AlgometerStopCondition) msg.Condition;
            SupplyPressure = msg.SupplyPressure;

            if (State == AlgometerState.STATE_STIMULATING) 
            {
                _channels[0].Add(msg.ActualPressure01, msg.TargetPressure01);
                _channels[1].Add(msg.ActualPressure02, msg.TargetPressure02);
                vasScore.Add(msg.VasScore);

                Log.Debug("Force = {0:0.00}, {1:0.00}, Vas = {2:0.00}", msg.ActualPressure01, msg.TargetPressure01, msg.VasScore);
            }

            _channels[0].FinalPressure = msg.FinalPressure01;
            _channels[1].FinalPressure = msg.FinalPressure02;
            FinalRating = msg.FinalVasScore;
            CurrentRating = msg.VasScore;
            VasReady = msg.VasIsLow;
            VasConnected = msg.VasConnected;
            PressureAvailable = !msg.CompressorRunning;
            UpdateError(msg);
        }

        private void UpdateError(StatusMessage msg)
        {
            if (State == AlgometerState.STATE_NOT_CONNECTED)
            {
                Error = "Connection failed";
            }
            else if (!msg.PowerOn)
            {
                Error = "Please turn on the CPAR device";
            }
            else if (State == AlgometerState.STATE_EMERGENCY)
            {
                Error = "Emergency button is activated";
            }
            else if (!msg.VasConnected)
            {
                Error = "Please connect the VAS meter";
            }
            else if (!msg.VasIsLow && (State == AlgometerState.STATE_IDLE))
            {
                Error = "Please set the VAS score to 0.0cm";
            }
            else if (msg.CompressorRunning)
            {
                Error = "Please wait for the compressor to turn off";
            }
            else
            {
                Error = "";
            }
        }

        private AlgometerState GetState(StatusMessage msg)
        {
            AlgometerState retValue = AlgometerState.STATE_NOT_CONNECTED;

            switch (msg.SystemState)
            {
                case StatusMessage.State.STATE_STIMULATING:
                    retValue = AlgometerState.STATE_STIMULATING;
                    break;

                case StatusMessage.State.STATE_IDLE:
                    retValue = AlgometerState.STATE_IDLE;
                    break;

                case StatusMessage.State.STATE_EMERGENCY:
                    retValue = AlgometerState.STATE_EMERGENCY;
                    break;

                default:
                    retValue = AlgometerState.STATE_NOT_CONNECTED;
                    break;
            }

            return retValue;
        }


        #endregion
        #region Device Definitions
        public enum PressureType
        {
            SUPPLY_PRESSURE = 0,
            STIMULATING_PRESSURE
        }

        public static readonly int UPDATE_RATE = 20;
        public static readonly double MAX_PRESSURE = 100;
        public static readonly double MAX_SUPPLY_PRESSURE = 1000;
        public static readonly double MAX_SCORE = 10;

        public static int TimeToRate(double time) => (int)Math.Round(time * UPDATE_RATE);

        public static double BinaryToPressure(byte x, PressureType type = PressureType.STIMULATING_PRESSURE) =>
            type == PressureType.SUPPLY_PRESSURE ? 
            MAX_SUPPLY_PRESSURE * ((double)x) / byte.MaxValue : 
            MAX_PRESSURE * ((double)x) / byte.MaxValue;

        public static double BinaryToScore(byte x) => MAX_SCORE * ((double)x) / byte.MaxValue;
        public static double PressureToBinary(double pressure) => (255.0 / 100.0) * pressure;
        public static double DeltaPressureToBinary(double delta) => (255.0 / 100.0) * (delta / UPDATE_RATE);
        public static double CountToTime(int count) => ((double)count) / UPDATE_RATE;
        public static ushort TimeToCount(double time) => (ushort)Math.Ceiling(time * UPDATE_RATE);
        #endregion
        #region IPressureAlgometer
        private readonly Timer timer;

        private static void OnTimer(object state)
        {
            if (state is CPARDevice device)
            {
                try
                {
                    if (device.PingEnabled)
                    {
                        device.Ping();
                    }
                }
                catch 
                {
                    device.PingEnabled = false;
                    device.State = AlgometerState.STATE_NOT_CONNECTED;
                }
            }
        }

        public override int Ping()
        {
            var pingFunction = new LabBench.CPAR.Functions.KickWatchdog();
            Execute(pingFunction);
            return (int) pingFunction.Counter;
        }

        double IPressureAlgometer.MaximalPressure => MAX_PRESSURE;

        double IPressureAlgometer.SamplePeriod => 1 / ((double)UPDATE_RATE);

        private AlgometerState _state = AlgometerState.STATE_IDLE;

        public AlgometerState State
        {
            get {  lock(LockObject) { return _state; } }
            private set => SetPropertyLocked(ref _state, value);
        }

        private bool _vasReady = false;

        public bool VasReady
        {
            get { lock (LockObject) { return _vasReady; } }
            private set => SetPropertyLocked(ref _vasReady, value);
        }

        private bool _vasConnected = false;

        public bool VasConnected
        {
            get { lock (LockObject) { return _vasConnected; } }
            private set => SetPropertyLocked(ref _vasConnected, value);
        }

        private bool _pressureAvailable = false;

        public bool PressureAvailable
        {
            get { lock (LockObject) { return _pressureAvailable; } }
            private set => SetPropertyLocked(ref _pressureAvailable, value);
        }

        private string _error;

        public string Error
        {
            get { lock (LockObject) { return _error; } }
            private set => SetPropertyLocked(ref _error, value);
        }

        private double _supplyPressure;

        public double SupplyPressure
        {
            get { lock (LockObject) { return _supplyPressure; } }
            private set => SetPropertyLocked(ref _supplyPressure, value);
        }

        public IList<double> Rating => vasScore.AsReadOnly();

        private double _finalRating = 0;

        public double FinalRating
        {
            get { lock (LockObject) { return _finalRating; } }
            private set => SetPropertyLocked(ref _finalRating, value);
        }

        private double _currentRating = 0;

        public double CurrentRating
        {
            get { lock (LockObject) { return _currentRating; } }
            private set => SetPropertyLocked(ref _currentRating, value);
        }

        private AlgometerStopCondition _stopCondition;

        public AlgometerStopCondition StopCondition
        {
            get { lock (LockObject) { return _stopCondition; } }
            private set => SetPropertyLocked(ref _stopCondition, value);
        }

        public IList<IPressureChannel> Channels => (from c in _channels select c as IPressureChannel).ToList();

        public void Start(AlgometerStopCriterion criterion, bool forcedStart)
        {
            if (forcedStart)
            {
                var function = new ForceStartStimulation()
                {
                    Criterion = criterion == AlgometerStopCriterion.STOP_CRITERION_ON_BUTTON ?
                                ForceStartStimulation.StopCriterion.STOP_CRITERION_ON_BUTTON :
                                ForceStartStimulation.StopCriterion.STOP_CRITERION_ON_BUTTON_VAS
                };
                Execute(function);
                PingEnabled = true;
            }
            else
            {
                var function = new StartStimulation()
                {
                    Criterion = criterion == AlgometerStopCriterion.STOP_CRITERION_ON_BUTTON ?
                                             StartStimulation.StopCriterion.STOP_CRITERION_ON_BUTTON :
                                             StartStimulation.StopCriterion.STOP_CRITERION_ON_BUTTON_VAS

                };
                Execute(function);
                PingEnabled = true;
            }
            
        }

        public void Stop()
        {
            Execute(new StopStimulation());
            PingEnabled = false;
        }

        public void Reset()
        {
            vasScore.Clear();
            Notify(nameof(Rating));
            _channels.ForEach((c) => c.Reset());
        }

        private readonly List<double> vasScore = new List<double>();
        private List<PressureChannel> _channels = new List<PressureChannel>();
        #endregion
    }
}
