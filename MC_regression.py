#//////////////////////////////////////////////////////////////////////////////////////////////////////////////////#
#///////////////////////// Copyright A 2022 Vivartan Technologies., All rights reserved////////////////////////////#
#//////////////////////////////////////////////////////////////////////////////////////////////////////////////////#
#//                                                                                                              //#
#//All works published under Zilla_Gen_0 by Vivartan Technologies is copyrighted by the Association and ownership//# 
#//of all right, title and interest in and to the works remains with Vivartan Technologies. No works or documents//#
#//published under Zilla_Gen_0 by Vivartan Technologies may be reproduced,transmitted or copied without the expre//#
#//-ss written permission of Vivartan Technologies will be considered as a violations of Copyright Act and it may//#
#//lead to legal action.                                                                                         //#
#//////////////////////////////////////////////////////////////////////////////////////////////////////////////////#
#//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#
#* File Name : frame_formatter_regression.py
#
#* Purpose :
#
#* Creation Date : 24-08-2023
#
#* Last Modified : Thu 23 Mar 2023 12:25:34 AM IST
#
#* Created By :  
#
#///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#

#!/usr/bin/python

import subprocess
import os
import random
import shutil
import sys
import glob
import re
from datetime import datetime

def main():
    #print_banner("Project-ALU Verification")

    simulate_flag = True
    pwd = os.getcwd()
    day, mon = datetime.now().day, datetime.now().month
    date = "{:02d}_{:02d}".format(day, mon + 1)
    regdir = "{}/{}_regression_result".format(pwd, date)
    if not os.path.exists(regdir):
        os.makedirs(regdir)

    input_file = sys.argv[1]
    cov_en = sys.argv[2] if len(sys.argv) > 2 else None

    tests = discover_tests(input_file)

    for test in tests:
        simulate_test(test, cov_en, regdir)

    if simulate_flag:
        report_test(tests, regdir, date, cov_en)


def print_banner(text):
    subprocess.call(["figlet", "-c", text])

def discover_tests(input_file):
    tests = []
    with open(input_file, 'r') as file:
        for line in file:
            line = line.strip()
            parts = line.split()
            if parts:
                if len(parts) == 2 and parts[1].isdigit():
                    tests.extend([parts[0]] * int(parts[1]))
                else:
                    tests.append(parts[0])
    return tests

def simulate_test(test, cov_en, regdir):
    seed = random.randint(0, 99999)
    simdir = "{}/{}_{}".format(regdir, test, seed)
    if not os.path.exists(simdir):
        os.makedirs(simdir)

#    cmd = ["irun", "-access", "+rwc", "-f", "./compile.f", "-svseed", str(seed),
#	"+define+ADDR_WIDTH=12", "+define+INSTR_WIDTH=32", "+define+DATA_WIDTH=32", "+define+PC_WIDTH=20", 
#	"+UVM_TESTNAME={}".format(test), "+define+UVM_REPORT_DISABLE_FILE_LINE",
#          "-uvmhome", "CDNS-1.1d"]
    cmd = ["irun", "-sv", "-access", "+rwc", "-f", "compile.f", "-svseed", str(seed),
	"+UVM_TESTNAME={}".format(test), "+define+UVM_REPORT_DISABLE_FILE_LINE",
          "-uvmhome", "CDNS-1.1d"]

    if cov_en:
        cmd.extend(["-coverage", "all", "-covdut", "i2c_wrapper",
                    "-covworkdir", "/cov_work", "-covoverwrite",
                    "-covfile", "./cov_files/cov_cmd.cf"])

    subprocess.call(cmd)
    shutil.move("irun.log", os.path.join(simdir, "irun.log"))

    if os.path.exists("waves.shm"):
        shutil.move("waves.shm", simdir)

    
def report_test(tests, regdir, date, cov_en):
    passed_tests = {}
    failed_tests = {}

    for test in tests:
        passed_seeds = []
        failed_seeds = []

        for seed in range(0, 100000):
            simdir = "{}/{}_{}".format(regdir, test, seed)
            log_file_path = os.path.join(simdir, "irun.log")

            if os.path.exists(log_file_path):
                with open(log_file_path, 'r') as log_file:
                    log_content = log_file.read()

                    pass_status = re.search(r"UVM_ERROR\s*:\s*0", log_content) and re.search(r"UVM_FATAL\s*:\s*0", log_content)

                if pass_status:
                    passed_seeds.append(seed)
                else:
                    failed_seeds.append(seed)

        if passed_seeds:
            passed_tests[test] = passed_seeds
        if failed_seeds:
            failed_tests[test] = failed_seeds

    with open("{}/{}_regression.log".format(regdir, date), "w") as report_file:
        report_file.write("REGRESSION RESULTS\n")
        report_file.write("==================\n\n")
        report_file.write("PASSED TESTS: {}\n".format(len(passed_tests)))
        for test, seeds in passed_tests.items():
            report_file.write("test_name: {}  seeds: {}\n".format(test, ", ".join(map(str, seeds))))
        report_file.write("\n----------------\n")
        report_file.write("FAILED TESTS: {}\n".format(len(failed_tests)))
        for test, seeds in failed_tests.items():
            report_file.write("test_name: {}  seeds: {}\n".format(test, ", ".join(map(str, seeds))))

    with open("{}/{}_regression.log".format(regdir, date), 'r') as file:
        print(file.read())

        if cov_en:
            subprocess.call(["imc", "-exec", "cov_files/cov_merge.cmd"])

    subprocess.call(["rm", "-rf", "i*"])


if __name__ == "__main__":
    main()

