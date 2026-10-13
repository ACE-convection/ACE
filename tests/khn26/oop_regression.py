#!/usr/bin/env python3
"""Freeze v0.20 and compare staged OOP candidates with isolated observations.

The runner never edits production source. Run fresh-process native/none/P3
prefixes and minute-output cases. --compare compares observation workspaces
without integration; candidate adapters preserve these observation points.
"""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shlex
import subprocess

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "115cc50db158f2a0f0ba55fca66027958a895060"
FILES = ["ace_input.F", "ace_interpolation.F", "microphy_p3.F", "ace_module.F", "test.F"]
INPUT_HASH = "09408f4d0343afd8659df82f8f1cfe5dc59308cff150fb2bcfd569b1b8794d35"
TABLE_HASH = "57d2e839b4bbc52fa15892ac47d04a76c0854577a5df34dae264e55bdad4baf3"


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f"Expected one observation anchor: {old[:90]!r}")
    return source.replace(old, new, 1)



RESPONSE_FIELDS = ("coarse_nz", "coarse_ratio", "coarse_z", "coarse_ze", "coarse_F", "dwdt", "PMB", "PMDv", "PMD",
                   "slab_geometry", "zero_ref_buoyancy", "Wbar_eq_zero", "turn_off_DHv", "turn_off_DHh")


def response_code(source):
    """Map test hook expressions to context components, preserving literals/comments."""
    chunks = re.split(r"('(?:[^']|'')*'|\"(?:[^\"]|\"\")*\"|![^\n]*)", source)
    pattern = r"\b(" + "|".join(RESPONSE_FIELDS) + r")\b"
    return "".join(c if i % 2 else re.sub(pattern, lambda m: "response%" + m[0], c)
                   for i, c in enumerate(chunks))


def thermal_code(source, prefix="thermal%"):
    """Qualify cache expressions without changing labels or numerical formulas."""
    chunks = re.split(r"('(?:[^']|'')*'|\"(?:[^\"]|\"\")*\"|![^\n]*)", source)
    return "".join(c if i % 2 else re.sub(r"\b(reference_tv|Ta|q|ql|qi)\b",
                                         lambda m: prefix + m[0], c)
                   for i, c in enumerate(chunks))


def candidate_stage(source):
    if "procedure :: diagnose => model_diagnose" in source:
        return "OOP-4a"
    if "procedure :: integrate => model_integrate" in source:
        return "OOP-3b"
    if "type :: ace_response_t" in source:
        return "OOP-3a"
    return "OOP-2" if "procedure :: initialize => model_initialize" in source else "OOP-1"


def observe(source):
    declarations = """
interface oop_dump
  module procedure oop_dump1, oop_dump2, oop_dump3, oop_dump4
end interface
"""
    source = replace_once(source, "\ncontains\n\nsubroutine ace_driver",
                          declarations + "\ncontains\n\nsubroutine ace_driver")
    initialization_hook = """
call oop_dump('reference_tv', reference_tv)
call oop_dump('coarse_z', coarse_z)
call oop_dump('coarse_ze', coarse_ze)
block
  character(8) :: tables
  call get_environment_variable('ACE_OOP_TABLES',tables)
  if (trim(tables)=='1') then
    call oop_dump('PMB',PMB)
    if (allocated(PMDv)) call oop_dump('PMDv',PMDv)
    if (allocated(PMD)) call oop_dump('PMD',PMD)
  endif
end block
end subroutine ace_initialization"""
    thermal_owned = "type :: ace_thermal_t" in source
    contextual = "type :: ace_response_t" in source
    if thermal_owned:
        initialization_hook = thermal_code(initialization_hook)
    if contextual:
        initialization_hook = response_code(initialization_hook).replace("end subroutine ace_initialization", "end subroutine ace_initialization_context")
    source = replace_once(source, "end subroutine ace_initialization_context" if contextual else "end subroutine ace_initialization", initialization_hook)
    tendency_hook = """
call oop_dump('tendency',dXdt)
call oop_dump('rho0B',rho0B)
call oop_dump('F',F)
call oop_dump('coarse_F',coarse_F)
call oop_dump('dwdt',dwdt)
call oop_dump('Ta_stage',Ta)
call oop_dump('q_stage',q)
call oop_dump('ql_stage',ql)
call oop_dump('qi_stage',qi)
end subroutine ace_tendency"""
    if thermal_owned:
        tendency_hook = thermal_code(tendency_hook)
    if contextual:
        tendency_hook = response_code(tendency_hook).replace("end subroutine ace_tendency", "end subroutine ace_tendency_context")
    source = replace_once(source, "end subroutine ace_tendency_context" if contextual else "end subroutine ace_tendency", tendency_hook)
    ownership_guard = "if (allocated(legacy_response%PMB)) error stop 'Model used legacy response storage'\n"
    if thermal_owned:
        ownership_guard += "if (allocated(legacy_thermal%reference_tv) .or. allocated(legacy_thermal%Ta) .or. &\n" \
                           "    allocated(legacy_thermal%q) .or. allocated(legacy_thermal%ql) .or. &\n" \
                           "    allocated(legacy_thermal%qi)) error stop 'Model used legacy thermal storage'\n"
        source = replace_once(source, "! Synchronous bridge for validation/serialization until output extraction.",
                              ownership_guard + "! Synchronous bridge for validation/serialization until output extraction.")
        source = replace_once(source, "logical, intent(in), optional :: reset_clock_to_target\ncall ace_driver_context(self%response",
                              "logical, intent(in), optional :: reset_clock_to_target\n" + ownership_guard + "call ace_driver_context(self%response")
    elif contextual:
        source = replace_once(source, "! Synchronous bridge to the unchanged procedural integration/output path.",
                              ownership_guard + "! Synchronous bridge to the unchanged procedural integration/output path.")
    source = replace_once(source, "  ! call physics here", "  call oop_dump('before_physics',X)\n  ! call physics here")
    source = replace_once(source, "  ! implicit damping ", "  call oop_dump('after_physics',X)\n  ! implicit damping ")
    source = replace_once(source, "  call ImDamp(ncols,nz,n_prog,X,Ref,dt)",
                          "  call ImDamp(ncols,nz,n_prog,X,Ref,dt)\n  call oop_dump('after_damping',X)")
    sink_end = "end subroutine precip_sinks_context" if thermal_owned else "end subroutine precip_sinks"
    source = replace_once(source, sink_end,
                          "call oop_dump('native_sinks',dXdt)\n" + sink_end)
    source = replace_once(source, "end subroutine ImDamp",
                          "call oop_dump('damp',damp)\nend subroutine ImDamp")
    source = replace_once(source, "itt = itt + 1", """
call oop_dump('p3_liquid_flux',precip_liq)
call oop_dump('p3_solid_flux',precip_sol)
itt = itt + 1""")
    helpers = ""
    for rank in range(1, 5):
        dims = ",".join(":" for _ in range(rank))
        helpers += f"""
subroutine oop_dump{rank}(label,values)
character(*),intent(in)::label
real,intent(in)::values({dims})
character(2048)::directory
integer::unit,stat
call get_environment_variable('ACE_OOP_OBSERVATIONS',directory)
if (len_trim(directory)==0) return
open(newunit=unit,file=trim(directory)//'/'//label//'.bin', &
     access='stream',form='unformatted',status='unknown',position='append',iostat=stat)
if(stat/=0) error stop 'Cannot open OOP observation'
write(unit) values
close(unit)
end subroutine
"""
    source = replace_once(source, "end module", helpers + "\nend module")
    return source


def compare_file(a, b):
    """Bitwise comparison; chunk differences locate the first raw element."""
    a, b = Path(a), Path(b)
    report = {"baseline_sha256": sha(a), "candidate_sha256": sha(b),
              "baseline_bytes": a.stat().st_size, "candidate_bytes": b.stat().st_size}
    report["bitwise_identical"] = report["baseline_sha256"] == report["candidate_sha256"]
    if report["bitwise_identical"]:
        return report
    if a.stat().st_size != b.stat().st_size:
        report["first_divergence"] = "file size / record count"
        return report
    skip, dtype = 0, "<f8"
    if a.name in {"states.bin", "initialization.bin"}:
        skip = 12 if a.name == "states.bin" else 16
        with a.open("rb") as x, b.open("rb") as y:
            if x.read(skip) != y.read(skip):
                report["first_divergence"] = "integer stream header"
                return report
    if a.name == "fields.bin": dtype = "<f4"
    itemsize = np.dtype(dtype).itemsize
    if (a.stat().st_size-skip) % itemsize:
        report["first_divergence"] = "truncated numeric payload"
        return report
    av, bv = np.memmap(a, dtype, mode="r",offset=skip), np.memmap(b, dtype, mode="r",offset=skip)
    bit_dtype = "<u8" if itemsize == 8 else "<u4"
    maximum, diff_square, ref_square = 0., 0., 0.
    for offset in range(0, av.size, 1024 * 1024):
        x, y = av[offset:offset + 1024 * 1024], bv[offset:offset + 1024 * 1024]
        mismatch = np.flatnonzero(x.view(bit_dtype) != y.view(bit_dtype))
        if mismatch.size and "first_element" not in report:
            i = int(mismatch[0])
            report.update(first_element=offset+i, baseline_value=float(x[i]), candidate_value=float(y[i]),
                          first_byte_offset=skip+(offset+i)*itemsize,
                          baseline_bits=f"{int(x.view(bit_dtype)[i]):0{itemsize*2}x}",
                          candidate_bits=f"{int(y.view(bit_dtype)[i]):0{itemsize*2}x}",
                          first_absolute_error=float(abs(y[i]-x[i])),
                          first_relative_error=float(abs((y[i]-x[i])/x[i])) if x[i] else None)
        # Error reporting only; widen real32 to avoid diagnostic overflow.
        x, y = x.astype(np.float64), y.astype(np.float64)
        delta = y - x
        maximum = max(maximum, float(np.max(np.abs(delta))))
        diff_square += float(np.sum(delta*delta))
        ref_square += float(np.sum(x*x))
    report.update(max_absolute_error=maximum,
                  relative_l2=(diff_square/ref_square)**.5 if ref_square else None,
                  zero_reference_policy="relative error undefined when reference is zero")
    if a.name == "states.bin":
        n,z,nv = map(int,np.fromfile(a,"<i4",count=3))
        size = (n+1)*z*nv
        index = report["first_element"]
        if size <= index < size+z:
            report["first_location"] = {"block":"initial Tv0", "level":index-size}
        else:
            stream_index = index if index < size else index-z
            frame, local = divmod(stream_index,size)
            ace, level, var = map(int,np.unravel_index(local,(n+1,z,nv),order="F"))
            labels = ["MF","theta_e","qt"] if nv==3 else ["MF","theta","qv","qc","nc","qr","nr","qi","ni","qrim","brim"]
            report["first_location"] = {"saved_frame":frame,"ACE":ace,"level":level,"variable":labels[var],"indices":"zero-based"}
    return report


def compare_dirs(a, b):
    paths_a = {str(p.relative_to(a)) for p in a.rglob("*.bin")}
    paths_b = {str(p.relative_to(b)) for p in b.rglob("*.bin")}
    report = {"missing": sorted(paths_a-paths_b), "extra": sorted(paths_b-paths_a), "files": {}}
    for path in sorted(paths_a & paths_b):
        report["files"][path] = compare_file(a/path, b/path)
    report["passed"] = bool(paths_a) and not report["missing"] and not report["extra"] and all(
        x["bitwise_identical"] for x in report["files"].values())
    return report


def analyze_existing(work):
    """Record observation layouts/counts and validate the frozen state streams."""
    result = json.loads((work/"results.json").read_text())
    if not result["passed"]:
        raise ValueError("Baseline observer gates did not pass")
    layouts, validity, precipitation = {}, {}, {}
    for physics in ("none", "native", "p3"):
        initial = work/f"runs/{physics}_initialize_production_plain/initialization.bin"
        n, z, nv, coarse = map(int, np.fromfile(initial, "<i4", count=4))
        initial_payload = np.memmap(initial,"<f8",mode="r",offset=16)
        x_size = (n+1)*z*nv
        ref = initial_payload[x_size:x_size+z*8].reshape((z,8),order="F")
        area = initial_payload[x_size+z*8:x_size+z*8+n]
        shapes = {
            "reference_tv": [z], "coarse_z": [coarse], "coarse_ze": [coarse+1],
            "PMB": [coarse,n,coarse+1,n], "PMDv": [n,n,coarse,coarse+1], "PMD": [n,n,coarse,coarse+1],
            "tendency": [n,z,nv], "rho0B": [n,z], "F": [n,z], "coarse_F": [n,coarse], "dwdt": [n,coarse+1],
            "Ta_stage": [n,z], "q_stage": [n,z], "ql_stage": [n,z], "qi_stage": [n,z],
            "before_physics": [n+1,z,nv], "after_physics": [n+1,z,nv], "after_damping": [n+1,z,nv],
            "native_sinks": [n,z,2], "damp": [z], "p3_liquid_flux": [n], "p3_solid_flux": [n],
        }
        for directory in sorted((work/"runs").glob(physics+"_*")):
            task = directory.name.split("_")[1]
            steps = 10 if task == "prefix" else 15 if task == "minute" else 0
            is_observed = directory.name.endswith("_observed")
            if is_observed:
                expected_labels = {"reference_tv", "coarse_z", "coarse_ze"}
                if task == "initialize" and physics == "native": expected_labels |= {"PMB", "PMDv", "PMD"}
                if steps:
                    expected_labels |= {"tendency", "rho0B", "F", "coarse_F", "dwdt", "Ta_stage", "q_stage", "ql_stage", "qi_stage",
                                        "before_physics", "after_physics", "after_damping", "damp"}
                    if physics == "native": expected_labels.add("native_sinks")
                    if physics == "p3": expected_labels |= {"p3_liquid_flux", "p3_solid_flux"}
                actual = {p.stem for p in (directory/"observations").glob("*.bin")}
                assert actual == expected_labels, (directory.name, actual ^ expected_labels)
                for path in (directory/"observations").glob("*.bin"):
                    shape = shapes[path.stem]
                    frame_bytes = int(np.prod(shape))*8
                    assert path.stat().st_size % frame_bytes == 0, path
                    frames = path.stat().st_size//frame_bytes
                    stage = path.stem in {"tendency", "rho0B", "F", "coarse_F", "dwdt", "Ta_stage", "q_stage", "ql_stage", "qi_stage"}
                    expected = 9*steps if stage else steps if path.stem in {
                        "before_physics", "after_physics", "after_damping", "damp", "native_sinks", "p3_liquid_flux", "p3_solid_flux"} else 1
                    assert frames == expected, (path,frames,expected)
                    layouts[str(path.relative_to(work))] = {
                        "dtype": "little-endian binary64", "shape_per_frame": shape, "array_order": "Fortran",
                        "frames": frames, "frame_axis": "RK stages 1..9 per step" if stage else "step" if expected == steps and steps else "initialization",
                        "stage_one_frame": "frame 0; then every ninth frame" if stage else None,
                    }
            state = directory/"states.bin"
            if state.exists():
                assert tuple(np.fromfile(state,"<i4",count=3)) == (n,z,nv)
                size = (n+1)*z*nv
                count = 11 if task == "prefix" else 2
                assert state.stat().st_size == 12 + 8*(count*size+z), state
                minima, maxima, mean_mf = [], [], []
                for frame in range(count):
                    offset = 12+frame*size*8+(z*8 if frame else 0)
                    values = np.memmap(state,"<f8",mode="r",offset=offset,shape=(size,)).reshape((n+1,z,nv),order="F")[:n]
                    assert np.isfinite(values).all(), (state,frame)
                    if physics == "p3":
                        assert (values[:,:,2:]>=0).all(), (state,frame)
                        assert (values[:,:,9]<=values[:,:,7]).all(), (state,frame)
                    else:
                        assert (values[:,:,2]>=0).all(), (state,frame)
                    minima.append(values.min(axis=(0,1)).tolist())
                    maxima.append(values.max(axis=(0,1)).tolist())
                    mean_mf.append(float(np.max(np.abs(np.sum(values[:,:,0]*(area/area.sum())[:,None],axis=0)))))
                validity[directory.name] = {"finite": True, "water_nonnegative": True,
                                           "qrim_not_above_qi": True if physics=="p3" else None,
                                           "saved_states":count,"field_minima":minima,"field_maxima":maxima,
                                           "max_abs_area_mean_MF_each_saved_state":mean_mf}
            if is_observed and steps and physics in {"native","p3"}:
                if physics == "native":
                    sink = np.memmap(directory/"observations/native_sinks.bin","<f8",mode="r").reshape((n,z,2,steps),order="F")
                    # Exclude the nonphysical final scalar slot, as in accepted diagnostics.
                    rate = -np.sum(sink[:,:z-1,1,:]*ref[:z-1,0][None,:,None]*ref[:z-1,4][None,:,None],axis=1)
                    definition = "actual column-integrated native removal equivalent"
                else:
                    liquid = np.memmap(directory/"observations/p3_liquid_flux.bin","<f8",mode="r").reshape((n,steps),order="F")
                    solid = np.memmap(directory/"observations/p3_solid_flux.bin","<f8",mode="r").reshape((n,steps),order="F")
                    rate = (liquid+solid)*1000.
                    definition = "P3 surface liquid+solid flux converted from m/s to mm/s"
                assert np.isfinite(rate).all() and (rate>=0).all(), directory
                amounts = rate.sum(axis=1)*4.
                precipitation[directory.name] = {"definition":definition,"duration_seconds":steps*4,
                                                  "ACE1_accumulation_mm":float(amounts[0]),
                                                  "area_mean_accumulation_mm":float(np.sum(amounts*area/area.sum())),
                                                  "finite_nonnegative":True}
            fields = directory/"fields.bin"
            if fields.exists():
                assert fields.stat().st_size == 2*n*z*9*4, fields
                assert np.isfinite(np.fromfile(fields,"<f4")).all(), fields
    evidence = {"passed":True, "state_validity":validity, "observation_layouts":layouts,"precipitation":precipitation,
                "integration_runner_sha256":sha(work/"executed_runner.py"), "analysis_runner_sha256":sha(Path(__file__)),
                "no_new_model_run":True,
                "coordinate_decoding":"Divide raw element index by product(shape_per_frame) for frame; unravel remainder in Fortran order. RK frame maps to step=frame//9+1, stage=frame%9+1. Indices in files are zero-based."}
    write(work/"observation_layouts.json", evidence)
    return evidence


def compile_compatibility(work):
    """Compile uninstrumented source in both kinds, serial/OpenMP; no model run."""
    includes = shlex.split(subprocess.check_output(["nf-config", "--fflags"], text=True))
    libs = shlex.split(subprocess.check_output(["nf-config", "--flibs"], text=True))
    directory = work/"compatibility"
    directory.mkdir(exist_ok=False)
    (directory/"executed_runner.py").write_bytes(Path(__file__).read_bytes())
    client = directory/"type_client.f90"
    client.write_text("program type_client\nuse ace_module, only: ace_t\nimplicit none\ntype(ace_t) :: model\nend program\n")
    report = {"cases": {}, "no_model_integration": True}
    for precision in (64,32):
        for omp in (False,True):
            name = f"real{precision}_"+("openmp" if omp else "serial")
            build = directory/name
            build.mkdir()
            flags = ["-cpp","-O2","-ffree-form","-ffree-line-length-none"]
            if precision == 64: flags += ["-fdefault-real-8","-fdefault-double-8"]
            if omp: flags += ["-fopenmp"]
            commands = []
            def execute(command,label):
                commands.append(command)
                with (build/(label+".log")).open("w") as log:
                    subprocess.run(command,cwd=build,stdout=log,stderr=subprocess.STDOUT,check=True)
            print(f"Compatibility build {name}",flush=True)
            for source in FILES:
                execute(["gfortran",*flags,*includes,"-c",str(work/"sources/plain"/source)],source)
            execute(["gfortran",*flags,*[n.replace(".F",".o") for n in FILES],*libs,"-o","ace_model.exe"],"model_link")
            execute(["gfortran",*flags,*includes,str(client),
                     *[n.replace(".F",".o") for n in FILES if n != "test.F"],*libs,"-o","type_client.exe"],"type_client_link")
            execute([str(build/"type_client.exe")],"type_client_run")
            report["cases"][name] = {"passed":True,"commands":commands,
                                    "model_executable_sha256":sha(build/"ace_model.exe"),
                                    "type_client_executable_sha256":sha(build/"type_client.exe")}
            write(directory/"results.json",report)
    report["passed"] = True
    write(directory/"results.json",report)
    return report


def run(work, lookup, candidate_baseline=None):
    work.mkdir(parents=True, exist_ok=False)
    input_file = ROOT/"data/input/manaus1342_khn26.nc"
    table = lookup/"p3_lookupTable_1.dat-v6.4-2momI"
    assert sha(input_file) == INPUT_HASH, "Input hash differs"
    assert sha(table) == TABLE_HASH, "Lookup hash differs"
    write(work/"status.json", {"state": "preparing"})
    (work/"executed_runner.py").write_bytes(Path(__file__).read_bytes())
    originals = {}
    for name in FILES:
        data = subprocess.check_output(["git", "show", f"{BASELINE}:fortran/src/{name}"], cwd=ROOT)
        if candidate_baseline is None:
            assert data == (ROOT/"fortran/src"/name).read_bytes(), f"Current production differs: {name}"
        else:
            data = (ROOT/"fortran/src"/name).read_bytes()
        originals[name] = data
    frozen = None
    if candidate_baseline is not None:
        frozen = json.loads((candidate_baseline/"results.json").read_text())
        assert frozen["passed"] and frozen["stage"] == "OOP-0"
        assert frozen["configuration"]["baseline_commit"] == BASELINE
        for path, evidence in frozen["artifacts"].items():
            actual = candidate_baseline/path
            assert actual.stat().st_size == evidence["bytes"] and sha(actual) == evidence["sha256"], path
    sources = {}
    for variant in ("plain", "observed"):
        source = work/"sources"/variant
        source.mkdir(parents=True)
        for name, data in originals.items():
            (source/name).write_bytes(data)
        if variant == "observed":
            (source/"ace_module.F").write_text(observe(originals["ace_module.F"].decode()))
        sources[variant] = source
    includes = shlex.split(subprocess.check_output(["nf-config", "--fflags"], text=True))
    libs = shlex.split(subprocess.check_output(["nf-config", "--flibs"], text=True))
    config = {"baseline_commit": BASELINE, "architecture_reference": "b3f922e48e238581a85d31469bafcb800569a748",
              "source_sha256": {n: hashlib.sha256(d).hexdigest() for n,d in originals.items()},
              "input": str(input_file), "input_sha256": INPUT_HASH, "lookup_directory": str(lookup),
              "lookup_sha256": TABLE_HASH, "compiler": subprocess.check_output(["gfortran", "--version"], text=True),
              "netcdf_flags": includes, "netcdf_libraries": libs, "threads": 32,
              "default_bubble_K": .25, "dt_seconds": 4, "prefix_steps": 10, "short_output_seconds": 60,
              "no_production_source_edit": candidate_baseline is None, "no_v024_features": True,
              "candidate_baseline_workspace": str(candidate_baseline) if candidate_baseline else None}
    write(work/"configuration.json", config)
    if frozen:
        for key in ("input_sha256", "lookup_sha256", "compiler", "netcdf_flags", "netcdf_libraries",
                    "threads", "default_bubble_K", "dt_seconds", "prefix_steps", "short_output_seconds"):
            assert config[key] == frozen["configuration"][key], f"Baseline configuration changed: {key}"
    if frozen:
        for name, data in originals.items():
            assert (ROOT/"fortran/src"/name).read_bytes() == data, f"Source changed during snapshot preparation: {name}"
    commands, builds = [], {}
    def execute(cmd, cwd, log, env=None):
        commands.append({"argv": cmd, "cwd": str(cwd), "log": str(log)})
        write(work/"commands.json", commands)
        with log.open("w") as stream:
            subprocess.run(cmd, cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True)
    for mode in ("production", "checked"):
        for variant in ("plain", "observed"):
            key = f"{mode}_{variant}"
            build = work/"builds"/key
            build.mkdir(parents=True)
            flags = ["-cpp", "-O2", "-ffree-form", "-ffree-line-length-none", "-fdefault-real-8", "-fdefault-double-8", "-fopenmp"]
            if mode == "checked":
                flags += ["-g", "-fcheck=all,no-array-temps", "-ffpe-trap=invalid,zero,overflow", "-fbacktrace"]
            write(work/"status.json", {"state": "building", "build": key})
            print(f"Building {key}", flush=True)
            for name in FILES:
                execute(["gfortran", *flags, *includes, "-c", str(sources[variant]/name)], build, build/(name+".log"))
            execute(["gfortran", *flags, *[n.replace(".F", ".o") for n in FILES], *libs, "-o", "ace_model.exe"],
                    build, build/"link.log")
            builds[key] = build/"ace_model.exe"
    env = os.environ.copy()
    env.update(OMP_NUM_THREADS="32", OMP_THREAD_LIMIT="32", OMP_DYNAMIC="FALSE", OMP_STACKSIZE="64M", OPENBLAS_NUM_THREADS="1")
    reports = {}
    for physics in ("none", "native", "p3"):
        for task in ("initialize", "prefix", "minute"):
            # The checked builds certify the prefix; interval IO is compared in production.
            modes = ("production", "checked") if task == "prefix" else ("production",)
            for mode in modes:
                outputs = {}
                for variant in ("plain", "observed"):
                    key = f"{physics}_{task}_{mode}_{variant}"
                    directory = work/"runs"/key
                    directory.mkdir(parents=True)
                    obs = directory/"observations"
                    obs.mkdir()
                    job_env = env.copy()
                    job_env.pop("ACE_OOP_OBSERVATIONS", None)
                    job_env.pop("ACE_OOP_TABLES", None)
                    if variant == "observed":
                        job_env["ACE_OOP_OBSERVATIONS"] = str(obs)
                        # Full tables once; subsequent cases retain exact initialization dump.
                        if task == "initialize" and physics == "native":
                            job_env["ACE_OOP_TABLES"] = "1"
                    cmd = [str(builds[f"{mode}_{variant}"]), "--input", str(input_file), "--physics", physics,
                           "--dt", "4", "--p3-lookup-directory", str(lookup)]
                    if task == "initialize":
                        cmd += ["--validate-input", str(directory/"initialization.bin")]
                    elif task == "prefix":
                        cmd += ["--steps", "10", "--state-output", str(directory/"states.bin")]
                    else:
                        cmd += ["--intervals", "1", "--state-output", str(directory/"states.bin"),
                                "--output", str(directory/"fields.bin")]
                    write(work/"status.json", {"state": "running", "job": key})
                    print(f"Running {key}", flush=True)
                    execute(cmd, directory, directory/"run.log", job_env)
                    outputs[variant] = directory
                names = ["initialization.bin"] if task == "initialize" else ["states.bin"]
                if task == "minute": names += ["fields.bin"]
                for name in names:
                    key = f"{physics}/{task}/{mode}/{name}"
                    reports[key] = compare_file(outputs["plain"]/name, outputs["observed"]/name)
                    if not reports[key]["bitwise_identical"]:
                        write(work/"results.json", {"passed": False, "first_failed_gate": key, "comparisons": reports})
                        raise ValueError(f"Observer changed baseline: {key}")
            if task == "prefix":
                for variant in ("plain", "observed"):
                    key = f"{physics}/checked_vs_production/{variant}"
                    reports[key] = compare_file(work/f"runs/{physics}_prefix_production_{variant}/states.bin",
                                                work/f"runs/{physics}_prefix_checked_{variant}/states.bin")
                    assert reports[key]["bitwise_identical"], key
                key = f"{physics}/checked_vs_production/observations"
                reports[key] = compare_dirs(work/f"runs/{physics}_prefix_production_observed/observations",
                                            work/f"runs/{physics}_prefix_checked_observed/observations")
                assert reports[key]["passed"], key
    artifacts = {}
    for path in (work/"runs").rglob("*.bin"):
        artifacts[str(path.relative_to(work))] = {"sha256": sha(path), "bytes": path.stat().st_size}
    preservation = None
    if frozen:
        preservation = compare_dirs(candidate_baseline/"runs", work/"runs")
        write(work/"baseline_comparison.json", preservation)
        assert preservation["passed"], "Candidate diverged from frozen OOP-0 baseline"
    result = {"passed": True, "stage": candidate_stage(originals["ace_module.F"].decode()) if frozen else "OOP-0", "configuration": config, "comparisons": reports,
              "baseline_preservation": preservation, "artifacts": artifacts,
              "scope": "GNU real64 OpenMP 32; default 0.25 K bubble; dt=4; initialization, ten-step prefix, 60 s interval outputs; no three-hour rerun."}
    write(work/"results.json", result)
    write(work/"status.json", {"state": "completed", "passed": True})
    print("PASS: observational hooks preserve all baseline outputs", flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", type=Path)
    parser.add_argument("--lookup-directory", type=Path, default=Path("/scratch/peter50504/ACE_FORTRAN/input_data"))
    parser.add_argument("--compare", type=Path, help="Compare workspaces' *.bin files without running models")
    parser.add_argument("--analyze-existing", action="store_true", help="Validate recorded observation layouts and saved-state invariants without integration")
    parser.add_argument("--candidate-baseline", type=Path, help="Build current source and require exact preservation of a frozen OOP-0 workspace; never reruns the baseline")
    parser.add_argument("--compile-compatibility", action="store_true", help="Compile serial/OpenMP real64/real32 from an existing source snapshot and run only an empty ace_t client")
    args = parser.parse_args()
    if sum(bool(x) for x in (args.candidate_baseline,args.compare,args.analyze_existing,args.compile_compatibility)) > 1:
        parser.error("Choose one execution or postprocessing mode")
    if args.compile_compatibility:
        compile_compatibility(args.work.resolve())
    elif args.analyze_existing:
        if args.compare: parser.error("Choose analysis or comparison")
        evidence = analyze_existing(args.work.resolve())
        print(f"PASS: {len(evidence['observation_layouts'])} observation layouts and {len(evidence['state_validity'])} state streams")
    elif args.compare:
        report = compare_dirs(args.work.resolve(), args.compare.resolve())
        write(args.compare.resolve()/"oop_comparison.json", report)
        print(json.dumps(report, indent=2))
        if not report["passed"]: raise SystemExit(1)
    else:
        work = args.work.resolve()
        try:
            run(work, args.lookup_directory.resolve(), args.candidate_baseline.resolve() if args.candidate_baseline else None)
        except Exception as exc:
            if work.exists(): write(work/"failure.json", {"type": type(exc).__name__, "message": str(exc)})
            raise


if __name__ == "__main__":
    main()
