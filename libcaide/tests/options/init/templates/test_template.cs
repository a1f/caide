using System;
using System.Diagnostics;
using System.Linq;
using System.IO;

public class Test
{
    private static Process Run(string exe, string args)
    {
        var psi = new ProcessStartInfo(exe, args)
        {
            UseShellExecute = false,
            WorkingDirectory = Directory.GetCurrentDirectory(),
        };
        return Process.Start(psi);
    }

    public static void Main(string[] args)
    {
        // Read path to caide executable from a file in current directory
        string testDir = ".";
        string caideExeFile = Path.Combine(testDir, "caideExe.txt");
        if (!File.Exists(caideExeFile))
        {
            testDir = Path.Combine(".caideproblem", "test");
            caideExeFile = Path.Combine(testDir, "caideExe.txt");
        }
        if (!File.Exists(caideExeFile))
        {
            throw new InvalidOperationException("Test must be run from either problem directory or .caideproblem/test subdirectory");
        }
        string caideExe = File.ReadAllText(caideExeFile).Trim();

        // Prepare the list of test cases in correct order; add recently created test cases too.
        Process updateTestsProcess = Run(caideExe, "update_tests");
        updateTestsProcess.WaitForExit();
        if (updateTestsProcess.ExitCode != 0)
        {
            Console.Error.WriteLine("caide update_tests returned non-zero error code " + updateTestsProcess.ExitCode);
        }

        // Process each test case described in a file in current directory
        foreach (string line in File.ReadAllLines(Path.Combine(testDir, "testList.txt")))
        {
            string[] words = line.Split(' ');
            string testName = words[0], testState = words[1];
            if (testState == "Skip")
            {
                Console.Error.WriteLine("Skipping test " + testName);
                // mark test as skipped
                File.WriteAllText(Path.Combine(testDir, testName + ".skipped"), "");
            }
            else if (testState == "Run")
            {
                Console.Error.WriteLine("Running test " + testName);
                TextWriter output = new StringWriter();

                using (TextReader input = new StreamReader(Path.Combine(testDir, testName + ".in")))
                {
                    try
                    {
                        Solution solution = new Solution();
                        solution.solve(input, output);
                    }
                    catch
                    {
                        Console.Error.WriteLine("Test " + testName + " threw an exception");
                        // mark test as failed
                        File.WriteAllText(Path.Combine(testDir, testName + ".failed"), "");
                    }
                }

                // save program output
                string result = output.ToString();
                File.WriteAllText(Path.Combine(testDir, testName + ".out"), result);

                // optional: print program output to stderr
                if (result.Length > 100)
                    result = result.Substring(0, 100) + "[...] (output truncated)\n";
                Console.Error.WriteLine(result);
            }
            else
            {
                // internal caide error: unknown test status
                File.WriteAllText(Path.Combine(testDir, testName + ".error"), "");
            }
        }

        // optional: evaluate tests automatically
        Process evalTestsProcess = Run(caideExe, "eval_tests");
        evalTestsProcess.WaitForExit();
        if (evalTestsProcess.ExitCode != 0)
        {
            Console.Error.WriteLine("Tests failed (exit code: " + evalTestsProcess.ExitCode + " )");
            Environment.Exit(evalTestsProcess.ExitCode);
        }
    }
}

