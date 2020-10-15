using Inventors.ECP;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace LabBench.CPAR.Tester
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        public static RoutedCommand OpenDeviceCmd = new RoutedCommand();
        private CPARDevice device;

        public MainWindow()
        {
            InitializeComponent();
            device = new CPARDevice
            {
                Location = Location.Parse("COM18")
            };
        }

        private void CommandBinding_Executed(object sender, ExecutedRoutedEventArgs e)
        {
            if (device.IsOpen)
            {
                device.Close();
            }

            Close();
        }

        private void ExitPossible(object sender, CanExecuteRoutedEventArgs e)
        {
            e.CanExecute = true;
        }

        // ExecutedRoutedEventHandler for the custom color command.
        private void OpenDeviceCmdExecuted(object sender, ExecutedRoutedEventArgs e)
        {
            device.Open();
        }

        // CanExecuteRoutedEventHandler for the custom color command.
        private void OpenDeviceCmdCanExecute(object sender, CanExecuteRoutedEventArgs e)
        {
            e.CanExecute = !device.IsOpen;
        }

        private void CloseDeviceCmdCanExecute(object sender, CanExecuteRoutedEventArgs e) => e.CanExecute = device.IsOpen;

        private void CloseDeviceCmdExecuted(object sender, ExecutedRoutedEventArgs e)
        {
            device.Close();
        }

        private void PingDeviceCmdCanExecute(object sender, CanExecuteRoutedEventArgs e) => e.CanExecute = device.IsOpen;

        private void PingDeviceCmdExecuted(object sender, ExecutedRoutedEventArgs e)
        {
            try
            {
                MessageBox.Show("Ping: " + device.Ping().ToString());
            }
            catch (Exception ex)
            {
                MessageBox.Show("Ping failed: " + ex.Message);
            }
        }
    }
}
