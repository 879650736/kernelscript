(** KernelScript Compiler - Advanced Multi-Program Pipeline
    
    Advanced Multi-Program Compilation Pipeline:
    Parser → Multi-Program Analyzer → Enhanced Type Checker → 
    Multi-Program IR Optimizer → Advanced Multi-Target Code Generator
*)

open Kernelscript
open Printf
open Multi_program_analyzer
open Multi_program_ir_optimizer

(** Command line options *)
type options = {
  input_file: string;
  output_dir: string option;
  verbose: bool;
  generate_makefile: bool;
  builtin_path: string option;
}

let default_opts = {
  input_file = "";
  output_dir = None;
  verbose = false;
  generate_makefile = true;
  builtin_path = None;
}

(** Argument parsing *)
let rec parse_args_aux opts = function
  | [] -> opts
  | "-o" :: output :: rest -> parse_args_aux { opts with output_dir = Some output } rest
  | "--output" :: output :: rest -> parse_args_aux { opts with output_dir = Some output } rest
  | "-v" :: rest -> parse_args_aux { opts with verbose = true } rest
  | "--verbose" :: rest -> parse_args_aux { opts with verbose = true } rest
  | "--no-makefile" :: rest -> parse_args_aux { opts with generate_makefile = false } rest
  | "--builtin-path" :: path :: rest -> parse_args_aux { opts with builtin_path = Some path } rest
  | arg :: rest when not (String.starts_with ~prefix:"-" arg) ->
      parse_args_aux { opts with input_file = arg } rest
  | unknown :: _ ->
      printf "Unknown option: %s\n" unknown;
      printf "Usage: kernelscript [options] <input_file>\n";
      printf "Options:\n";
      printf "  -o, --output <dir>     Specify output directory\n";
      printf "  -v, --verbose          Enable verbose output\n";
      printf "  --no-makefile          Don't generate Makefile\n";
      printf "  --builtin-path <path>  Specify path to builtin KernelScript files\n";
      exit 1

let parse_args () =
  let args = List.tl (Array.to_list Sys.argv) in
  let opts = parse_args_aux default_opts args in
  if opts.input_file = "" then (
    printf "Error: No input file specified\n";
    printf "Usage: kernelscript [options] <input_file>\n";
    exit 1
  );
  opts

(** Compilation phase tracking *)
type compilation_phase = 
  | Parsing
  | SymbolAnalysis  
  | MultiProgramAnalysis
  | TypeChecking
  | IROptimization
  | CodeGeneration

let string_of_phase = function
  | Parsing -> "Parsing"
  | SymbolAnalysis -> "Symbol Analysis"
  | MultiProgramAnalysis -> "Multi-Program Analysis"
  | TypeChecking -> "Type Checking & AST Enhancement"
  | IROptimization -> "Multi-Program IR Optimization"
  | CodeGeneration -> "Code Generation"

(** List utility functions *)
let rec take n = function
  | [] -> []
  | x :: xs when n > 0 -> x :: take (n - 1) xs
  | _ -> []

(** Code generation targets *)
type code_target =
  | EbpfC
  | UserspaceCoordinator

(** Unified compilation pipeline with multi-program analysis *)
let compile opts source_file =
  let current_phase = ref Parsing in
  
  try
    Printf.printf "\n🔥 KernelScript Compiler\n";
    Printf.printf "========================\n\n";
    Printf.printf "📁 Source: %s\n\n" source_file;
    
    (* Phase 1: Parse source file *)
    Printf.printf "Phase 1: %s\n" (string_of_phase !current_phase);
    let ic = open_in source_file in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    
    let lexbuf = Lexing.from_string content in
    let ast = 
      try
        Parser.program Lexer.token lexbuf
      with
      | exn ->
          let lexbuf_pos = Lexing.lexeme_start_p lexbuf in
          Printf.eprintf "❌ Parse error at line %d, column %d\n" 
            lexbuf_pos.pos_lnum 
            (lexbuf_pos.pos_cnum - lexbuf_pos.pos_bol);
          Printf.eprintf "   Last token read: '%s'\n" (Lexing.lexeme lexbuf);
          Printf.eprintf "   Exception: %s\n" (Printexc.to_string exn);
          Printf.eprintf "   Context: Failed to parse the input around this location\n";
          failwith "Parse error"
    in
    Printf.printf "✅ Successfully parsed %d declarations\n\n" (List.length ast);
    
    (* Phase 2: Symbol table analysis *)
    current_phase := SymbolAnalysis;
    Printf.printf "Phase 2: %s\n" (string_of_phase !current_phase);
    let symbol_table = Symbol_table.build_symbol_table ?builtin_path:opts.builtin_path ast in
    Printf.printf "✅ Symbol table created successfully\n\n";
    
    (* Phase 3: Multi-program analysis *)
    current_phase := MultiProgramAnalysis;
    Printf.printf "Phase 3: %s\n" (string_of_phase !current_phase);
    let multi_prog_analysis = analyze_multi_program_system ast in
    
    (* Extract config declarations *)
    let config_declarations = List.filter_map (function
      | Ast.ConfigDecl config -> Some config
      | _ -> None
    ) ast in
    Printf.printf "📋 Found %d config declarations\n" (List.length config_declarations);
    

    
    (* Phase 4: Enhanced type checking with multi-program context *)
    current_phase := TypeChecking;
    Printf.printf "Phase 4: %s\n" (string_of_phase !current_phase);
    let (annotated_ast, _typed_programs) = Type_checker.type_check_and_annotate_ast ?builtin_path:opts.builtin_path ast in
    Printf.printf "✅ Type checking completed with multi-program annotations\n\n";
    
    (* Phase 5: Multi-program IR optimization *)
    current_phase := IROptimization;
    Printf.printf "Phase 5: %s\n" (string_of_phase !current_phase);
    (* Generate optimized IR using the original function *)
    let optimized_ir = Multi_program_ir_optimizer.generate_optimized_ir annotated_ast multi_prog_analysis symbol_table source_file in
    
    (* Phase 6: Advanced multi-target code generation *)
    current_phase := CodeGeneration;
    Printf.printf "Phase 6: %s\n" (string_of_phase !current_phase);
    let resource_plan = plan_system_resources optimized_ir.programs multi_prog_analysis in
    let optimization_strategies = generate_optimization_strategies multi_prog_analysis in
    
    (* Extract type aliases from original AST *)
    let type_aliases = List.filter_map (function
      | Ast.TypeDef (Ast.TypeAlias (name, underlying_type)) -> Some (name, underlying_type)
      | _ -> None
    ) ast in
    
    (* Extract variable declarations with their original declared types *)
    let extract_variable_declarations ast_nodes =
      List.fold_left (fun acc node ->
        match node with
        | Ast.Program prog ->
            let func_decls = List.fold_left (fun acc2 func ->
              List.fold_left (fun acc3 stmt ->
                match stmt.Ast.stmt_desc with
                | Ast.Declaration (var_name, Some declared_type, _) ->
                    (match declared_type with
                     | Ast.UserType alias_name -> 
                         (* Only store type alias declarations *)
                         (var_name, alias_name) :: acc3
                     | _ -> acc3)
                | _ -> acc3
              ) acc2 func.Ast.func_body
            ) [] prog.Ast.prog_functions in
            func_decls @ acc
        | Ast.GlobalFunction func ->
            List.fold_left (fun acc2 stmt ->
              match stmt.Ast.stmt_desc with
              | Ast.Declaration (var_name, Some declared_type, _) ->
                  (match declared_type with
                   | Ast.UserType alias_name -> 
                       (* Only store type alias declarations *)
                       (var_name, alias_name) :: acc2
                   | _ -> acc2)
              | _ -> acc2
            ) acc func.Ast.func_body
        | _ -> acc
      ) [] ast_nodes
    in
    let variable_type_aliases = extract_variable_declarations ast in
    
    (* Generate eBPF C code using enhanced existing generator *)
    let ebpf_c_code = 
      if List.length config_declarations > 0 then
        Ebpf_c_codegen.compile_multi_to_c ~config_declarations ~type_aliases ~variable_type_aliases optimized_ir
      else
        Ebpf_c_codegen.compile_multi_to_c_with_analysis 
          ~type_aliases ~variable_type_aliases optimized_ir multi_prog_analysis resource_plan optimization_strategies in
      
    (* Determine output directory *)
    let base_name = Filename.remove_extension (Filename.basename source_file) in
    let output_dir = match opts.output_dir with
      | Some dir -> dir
      | None -> base_name
    in
    
    (* Generate userspace coordinator directly to output directory *)
    Userspace_codegen.generate_userspace_code_from_ir 
      ~config_declarations ~type_aliases optimized_ir ~output_dir source_file;
    
    (* Read the generated userspace code for preview *)
    let userspace_file = output_dir ^ "/" ^ base_name ^ ".c" in
    let userspace_c_code = 
      try
        let ic = open_in userspace_file in
        let content = really_input_string ic (in_channel_length ic) in
        close_in ic;
        content
      with _ -> "/* Failed to read generated userspace code */"
    in
    
    let generated_codes = [
      (EbpfC, ebpf_c_code);
      (UserspaceCoordinator, userspace_c_code);
    ] in
    
    Printf.printf "🎉 Compilation completed successfully!\n\n";
    
    (* Create output directory if it doesn't exist *)
    (try Unix.mkdir output_dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
    
    (* Compile required builtin headers based on program types *)
    let program_types = List.fold_left (fun acc decl ->
      match decl with
      | Ast.Program prog -> prog.Ast.prog_type :: acc
      | _ -> acc
    ) [] ast in
    
    let unique_program_types = List.sort_uniq compare program_types in
    List.iter (fun prog_type ->
      let (builtin_file, header_name) = match prog_type with
        | Ast.Xdp -> ("builtin/xdp.ks", "xdp.h")
        | Ast.Tc -> ("builtin/tc.ks", "tc.h")
        | Ast.Kprobe -> ("builtin/kprobe.ks", "kprobe.h")
        | _ -> ("", "")  (* Skip unsupported types *)
      in
      if builtin_file <> "" && Sys.file_exists builtin_file then (
        let output_header = Filename.concat output_dir header_name in
        try
          Printf.printf "🔧 Compiling builtin: %s -> %s\n" builtin_file output_header;
          Builtin_compiler.compile_builtin_file builtin_file output_header;
          Printf.printf "✅ Builtin header generated: %s\n" header_name
        with
        | exn ->
            Printf.eprintf "⚠️ Warning: Failed to compile builtin %s: %s\n" builtin_file (Printexc.to_string exn)
      )
    ) unique_program_types;
    
    Printf.printf "📤 Generated Code Outputs:\n";
    Printf.printf "=========================\n";
    List.iter (fun (target, code) ->
      let (target_name, filename) = match target with
        | EbpfC -> ("eBPF C Code", output_dir ^ "/" ^ base_name ^ ".ebpf.c")
        | UserspaceCoordinator -> ("Userspace Coordinator", output_dir ^ "/" ^ base_name ^ ".c")
      in
      
      (* Write eBPF file, userspace file is already written by userspace codegen *)
      (match target with
        | EbpfC -> 
          let oc = open_out filename in
          output_string oc code;
          close_out oc
        | UserspaceCoordinator -> 
          (* File already written by userspace codegen, just show preview *)
          ()
      );
      
      Printf.printf "\n--- %s → %s ---\n" target_name filename;
      let lines = String.split_on_char '\n' code in
      let preview_lines = take (min 10 (List.length lines)) lines in
      List.iter (Printf.printf "%s\n") preview_lines;
      if List.length lines > 10 then
        Printf.printf "... (%d more lines)\n" (List.length lines - 10);
    ) generated_codes;
    
    Printf.printf "\n✨ Multi-program compilation completed successfully!\n";
    Printf.printf "📁 Output directory: %s/\n" output_dir;
    
    (* Generate Makefile *)
    let makefile_content = Printf.sprintf {|# Multi-Program eBPF Makefile
# Generated by KernelScript compiler

# Compilers
BPF_CC = clang
CC = gcc

# BPF compilation flags
BPF_CFLAGS = -target bpf -O2 -Wall -Wextra -g
BPF_INCLUDES = -I/usr/include -I/usr/include/x86_64-linux-gnu

# Userspace compilation flags
CFLAGS = -Wall -Wextra -O2
LIBS = -lbpf -lelf -lz

# Object files
BPF_OBJ = %s.ebpf.o
USERSPACE_BIN = %s

# Source files
BPF_SRC = %s.ebpf.c
USERSPACE_SRC = %s.c

# Default target - build both eBPF and userspace programs
all: $(BPF_OBJ) $(USERSPACE_BIN)

# Compile eBPF C to object file
$(BPF_OBJ): $(BPF_SRC)
	$(BPF_CC) $(BPF_CFLAGS) $(BPF_INCLUDES) -c $< -o $@

# Compile userspace program
$(USERSPACE_BIN): $(USERSPACE_SRC) $(BPF_OBJ)
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)

# Clean generated files
clean:
	rm -f $(BPF_OBJ) $(USERSPACE_BIN)

# Run the userspace program
run: $(USERSPACE_BIN)
	sudo ./$(USERSPACE_BIN)

.PHONY: all clean run
|} base_name base_name base_name base_name in
    
    let makefile_path = output_dir ^ "/Makefile" in
    let oc = open_out makefile_path in
    output_string oc makefile_content;
    close_out oc;
    
    Printf.printf "📄 Generated Makefile: %s/Makefile\n" output_dir;
    Printf.printf "🔨 To compile: cd %s && make\n" output_dir;
    
  with
  | Failure msg when msg = "Parse error" ->
      Printf.eprintf "❌ Parse error in phase: %s\n" (string_of_phase !current_phase);
      exit 1
  | Type_checker.Type_error (msg, pos) ->
      Printf.eprintf "❌ Type error in phase %s at %s: %s\n" 
        (string_of_phase !current_phase) (Ast.string_of_position pos) msg;
      exit 1
  | exn ->
      Printf.eprintf "❌ Compilation failed in phase %s: %s\n" 
        (string_of_phase !current_phase) (Printexc.to_string exn);
      exit 1

(** Main entry point *)
let () =
  if Array.length Sys.argv < 2 then (
    Printf.printf "Usage: %s <source_file>\n" Sys.argv.(0);
    exit 1
  );
  
  let opts = parse_args () in
  
  compile opts opts.input_file 