using LabBench.CPAR.Functions;
using LabBench.Interface.Stimuli;
using LabBench.Interface.Stimuli.Analysis;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace LabBench.CPAR
{
    public class StimulusCompiler
    {
        private class Line
        {
            public double Time { get; set; }
            public double Value { get; set; }
            public double Slope { get; set; }
            public double Length { get; set; }
            public int Count { get; set; }
        }

        private void CompileLines(IStimulus stimulus)
        {
            lines = new List<Line>();
            var analyser = new TimeAnalyser();
            stimulus.Visit(analyser);
            analyser.TimePoints.Sort();           
            time = analyser.TimePoints.Distinct().ToArray();

            for (int n = 0; n < time.Length - 1; ++n)
            {
                lines.Add(new Line()
                {
                    Time = time[n],
                    Value = stimulus.GetValue(time[n]),
                    Slope = stimulus.GetSlope(time[n]),
                    Length = time[n + 1] - time[n],
                    Count = CPARDevice.TimeToCount(time[n + 1] - time[n])
                });
            }
        }

        private void CleanLines()
        {
            List<Line> output = new List<Line>();

            foreach (var line in lines)
            {
                if (line.Count > 0)
                {
                    output.Add(line);
                }
            }

            lines = output;
        }

        private void CompileInstructions()
        {
            double pressure = 0.0;

            foreach (var line in lines)
            {
                if (line.Slope == 0)
                {
                    Program.Instructions.Add(Instruction.Step(line.Value, line.Length));
                    pressure = line.Value;
                }
                else
                {
                    if (line.Value == pressure)
                    {
                        if (line.Slope > 0)
                        {
                            Program.Instructions.Add(Instruction.Increment(line.Slope, line.Length));
                        }
                        else
                        {
                            Program.Instructions.Add(Instruction.Decrement(-line.Slope, line.Length));
                        }
                    }
                    else
                    {
                        throw new ArgumentException("CPAR Does not support ramps that does not start from the current pressure pressure");
                    }
                }
            }
        }

        private SetWaveformProgram PerformCompile(IStimulus stimulus)
        {
            Program = new SetWaveformProgram();

            if (stimulus != null)
            {
                lines = new List<Line>();
                CompileLines(stimulus);
                CleanLines();
                CompileInstructions();
            }

            return Program;
        }

        public static SetWaveformProgram Compile(IStimulus stimulus)
        {
            if (instance is null)
            {
                instance = new StimulusCompiler();
            }

            return instance.PerformCompile(stimulus);
        }

        public SetWaveformProgram Program { get; private set; }

        private static StimulusCompiler instance = null;
        private double[] time;
        List<Line> lines;
    }
}
