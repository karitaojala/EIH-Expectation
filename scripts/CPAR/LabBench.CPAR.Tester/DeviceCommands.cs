using System;
using System.Collections.Generic;
using System.Text;
using System.Windows.Input;

namespace LabBench.CPAR.Tester
{
    public static class DeviceCommands
    {
        public static readonly RoutedUICommand Open =
            new RoutedUICommand("Open",
                                "Open",
                                typeof(DeviceCommands),
                                new InputGestureCollection() { new KeyGesture(Key.O, ModifierKeys.Control) });

        public static readonly RoutedUICommand Close =
            new RoutedUICommand("Close",
                                "Close",
                                typeof(DeviceCommands),
                                new InputGestureCollection() { new KeyGesture(Key.C, ModifierKeys.Control) });

        public static readonly RoutedUICommand Ping = new RoutedUICommand("Ping", "Ping", typeof(DeviceCommands));

    }
}
