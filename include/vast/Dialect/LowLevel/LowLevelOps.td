// Copyright (c) 2021-present, Trail of Bits, Inc.

#ifndef VAST_DIALECT_IR_LOWLEVELOPS
#define VAST_DIALECT_IR_LOWLEVELOPS

include "mlir/IR/OpBase.td"
include "mlir/IR/BuiltinAttributes.td"

include "mlir/Interfaces/ControlFlowInterfaces.td"

include "vast/Dialect/Core/Interfaces/SymbolInterface.td"
include "vast/Interfaces/ElementTypeInterface.td"

include "vast/Dialect/Core/CoreTraits.td"
include "vast/Dialect/Core/StorageInfo.td"
include "vast/Dialect/Core/Interfaces/DeclStorageInterface.td"
include "vast/Dialect/Core/Interfaces/SymbolInterface.td"
include "vast/Dialect/Core/Interfaces/SymbolTableInterface.td"

include "vast/Dialect/Core/Func.td"

// TODO(lukas): Add type constraints.
def LowLevel_StructGEPOp
  : LowLevel_Op< "gep", [] >
  , Arguments<(ins AnyType:$record, I32Attr:$idx, FlatSymbolRefAttr:$field)>
  , Results<(outs AnyType:$element)>
{
    let summary = "VAST struct gep  operation";
    let description = [{ VAST struct gep operation }];
}

def LowLevel_Subscript
    : LowLevel_Op< "subscript" >
    , Arguments<(ins
        AnyType:$array,
        AnyType:$index)>
    , Results<(outs AnyType:$result)>
{
  let summary = "VAST array subscript operator";
  let description = [{ VAST array subscript operator }];

  let assemblyFormat = [{
    $array `at` ` ` `[` $index `:` type($index) `]` attr-dict
      `:` type($array) `->` type($result)
  }];
}

def LowLevel_Alloca
    : LowLevel_Op< "alloca" >,
      Results<(outs AnyType:$result)>
{
    let summary = "Alloca for a piece of memory. For now does not support array types.";

    let assemblyFormat = [{
        attr-dict `:` type($result)
    }];
}

class PointerPointeeTypeMatch< string ptr, string val >
    : TypesMatchWith< "Inconsistent type between pointer and its value", ptr, val,
                      "(mlir::isa< ElementTypeInterface >($_self))"
                      "? mlir::cast< ElementTypeInterface >($_self).getElementType()"
                      ": mlir::Type{}" >;

def LowLevel_Load
    : LowLevel_Op< "load", [PointerPointeeTypeMatch<"ptr", "result"> ] >
    , Arguments<(ins ElementTypeInterface:$ptr)>
    , Results<(outs AnyType:$result)>
{
    let summary = "Load value from memory. Expects `hl.ptr` as pointer type.";

    let assemblyFormat = [{
        operands attr-dict `:` functional-type(operands, results)
    }];
}

def LowLevel_Store
    : LowLevel_Op< "store", [PointerPointeeTypeMatch<"ptr", "val">]>
    , Arguments<(ins AnyType:$val, ElementTypeInterface:$ptr)>
{
    let summary = "Store value into memory. Expects `hl.ptr` as pointer type.";

    let assemblyFormat = [{
        $ptr `,` $val attr-dict `:` type($ptr) `,` type($val)
    }];
}

def LowLevel_Cell
    : LowLevel_Op< "cell", [
        Core_VarSymbol,
        Core_DeclStorageInterface,
        DeclareOpInterfaceMethods< Core_DeclStorageInterface >
      ] >
    , Arguments<(ins
        SymbolNameAttr:$sym_name,
        Core_StorageClass:$storageClass,
        Core_ThreadStorage:$threadStorageClass
      )>
    , Results<(outs AnyType:$result)>
{
    let summary = "Cell that holds the value and is accessible trhough SSA result.";

    let assemblyFormat = [{
        $sym_name attr-dict custom< StorageClasses >($storageClass, $threadStorageClass)
        `:` type($result)
    }];
}

def LowLevel_CellInit
    : LowLevel_Op< "cell_init" >
    , Arguments<(ins AnyType:$var, Variadic<AnyType>:$elements)>
    , Results<(outs AnyType:$result)>
{
    let summary = "Cell initialization.";

    let assemblyFormat = [{
        operands attr-dict `:` functional-type(operands, results)
    }];

}

// FIXME: This is to be removed once cells are properly implemented.
def LowLevel_UninitializedVar
    : LowLevel_Op< "uninitialized_var", [Core_VarSymbol] >
    , Results<(outs AnyType:$result)>
{
    let summary = "Declaration of variable that have not been initialized yet.";
    let description = [{ Declaration of variable that have not been initialized yet. }];

    let results = (outs AnyType:$result);

    let assemblyFormat = [{
        attr-dict `:` type($result)
    }];
}

// FIXME: This is to be removed once cells are properly implemented.
def LowLevel_InitializeVar
    : LowLevel_Op< "initialize" >
    , Arguments<(ins AnyType:$var, Variadic<AnyType>:$elements)>
    , Results<(outs AnyType:$result)>
{
    let summary = "Initialize a variable.";
    let description = [{
        Initialize a variable - for now this operation is a direct lowering from hl.var
        initialization section. Later there will be need to discover how this ties
        to constructors.
    }];

    let assemblyFormat = [{
        operands attr-dict `:` functional-type(operands, results)
    }];
}

def LowLevel_Concat
    : LowLevel_Op< "concat" >
    , Arguments<(ins Variadic<AnyType>:$args)>
    , Results<(outs AnyType:$result)>
{
    let summary = "Concat integers together";
    let description = [{
        Concat operands together, where first argument occupies lsb.
    }];

    let assemblyFormat = [{
        operands attr-dict `:` functional-type(operands, results)
    }];
}

def LowLevel_Extract
    : LowLevel_Op< "extract" >
    , Arguments<(ins AnyType:$arg, TypedAttrInterface:$from, TypedAttrInterface:$to)>
    , Results<(outs AnyType:$result)>
{
    let summary = "Extracts value";
    let description = [{
        `0` is lsb, `[inc, exc)`
    }];

    let assemblyFormat = [{
        operands attr-dict `:` functional-type(operands, results)
    }];

    let builders = [
        OpBuilder<(ins "mlir::Type":$type,
                       "mlir::Value":$value, "std::size_t":$from, "std::size_t":$to),
        [{
            auto attr_type = mlir::IntegerType::get($_builder.getContext(),
                                                    64, mlir::IntegerType::Unsigned);
            $_state.addOperands(value);
            $_state.addAttribute("from", mlir::IntegerAttr::get(attr_type, from));
            $_state.addAttribute("to", mlir::IntegerAttr::get(attr_type, to));
            $_state.addTypes(type);
        }] >
    ];

    // TODO(ll): Utility API like size().

    let extraClassDeclaration = [{
        std::size_t from()
        {
            return mlir::dyn_cast< mlir::IntegerAttr >(getFrom()).getUInt();
        }

        std::size_t to()
        {
            return mlir::dyn_cast< mlir::IntegerAttr >(getTo()).getUInt();
        }

        std::size_t size()
        {
            return to() - from() + 1;
        }
    }];
}

def LowLevel_Br
    : LowLevel_Op< "br",
        [Terminator, DeclareOpInterfaceMethods<BranchOpInterface>]
      >
{
    let summary = "Direct branch.";
    let description = [{ Direct branch }];

    let successors = (successor AnySuccessor:$dest);
    let arguments = (ins Variadic<AnyType>:$operands);

    let builders = [
        OpBuilder< (ins "mlir::ValueRange":$operands, "mlir::SuccessorRange":$dest),
        [{
            $_state.addOperands(operands);
            $_state.addSuccessors(dest);
        }] >,

        OpBuilder< (ins "mlir::Block *":$dest),
        [{
            $_state.addSuccessors(dest);
        }] >
    ];

    let assemblyFormat = [{
        $dest (`(` $operands^ `:` type($operands) `)`)? attr-dict
    }];
}

def LowLevel_CondBr
    : LowLevel_Op< "cond_br", [Terminator, AttrSizedOperandSegments] >
    , Arguments<(ins AnyType:$cond, Variadic<AnyType>:$trueOperands, Variadic<AnyType>:$falseOperands )>
{
    let summary = "Conditional branch.";
    let description = [{ Direct branch }];

    let successors = (successor AnySuccessor:$trueDest, AnySuccessor:$falseDest);

    let builders = [
        OpBuilder< (ins
            "mlir::Value":$cond,
            "mlir::ValueRange":$trueOperands, "mlir::Block *":$trueDest,
            "mlir::ValueRange":$falseOperands, "mlir::Block *":$falseDest),
        [{
            build($_builder, $_state,
                  cond,
                  trueOperands, falseOperands,
                  trueDest, falseDest);
        }] >,
        OpBuilder< (ins
            "mlir::Value":$cond,
            "mlir::Block *":$trueDest,
            "mlir::Block *":$falseDest),
        [{
            build($_builder, $_state,
                  cond,
                  mlir::ValueRange(), mlir::ValueRange(),
                  trueDest, falseDest);
        }] >
    ];

    let assemblyFormat = [{
        $cond `:` type($cond) `,`
        $trueDest (`(` $trueOperands^ `:` type($trueOperands) `)`)? `,`
        $falseDest (`(` $falseOperands^ `:` type($falseOperands) `)`)?
        attr-dict
    }];
}

def LowLevel_ScopeRet
    : LowLevel_Op< "scope_ret", [Terminator] >
{
    let summary = "Terminator of scope.";
    let description = [{ Terminator of scopes (for example during lowering of loops). }];

    let assemblyFormat = [{attr-dict}];
}

def LowLevel_ScopeRecurse
    : LowLevel_Op< "scope_recurse", [Terminator] >
{
    let summary = "Jump to first block of scope.";
    let description = [{ Modelling continue. }];

    let assemblyFormat = [{attr-dict}];
}

def LowLevel_CondScopeRet
    : LowLevel_Op< "cond_scope_ret", [Terminator] >
{
    let summary = "Terminator of scope if condition is met, otherwise branch.";
    let description = [{ Terminate or branch. }];

    let successors = (successor AnySuccessor:$dest);
    let arguments = (ins AnyType:$cond, Variadic<AnyType>:$dest_operands);

    let builders = [

        OpBuilder< (ins "mlir::Value":$cond, "mlir::Block *":$dest),
        [{
            build($_builder, $_state, cond, mlir::ValueRange(), dest);
        }] >
    ];

    let assemblyFormat = [{
        $cond `:` type($cond) `,`
        $dest (`(` $dest_operands^ `:` type($dest_operands) `)`)? attr-dict
    }];}

def LowLevel_ReturnOp
    : LowLevel_Op< "return", [Terminator, Core_ReturnLikeTrait] >
    , Arguments<(ins Variadic<AnyType>:$result)>
{
    // Allow building a ReturnOp with no return operand.
    let builders = [
        OpBuilder<(ins), [{ build($_builder, $_state, std::nullopt); }]>
    ];

    let assemblyFormat = "($result^ `:` type($result))? attr-dict";
}

def LowLevel_Scope
    : LowLevel_Op< "scope", [
        NoRegionArguments,
        NoTerminator,
        Core_ScopeLikeTrait,
        Core_ShadowingSymbolTable< [
            [Core_VarSymbol, Core_TypeSymbol, Core_EnumConstantSymbol],
            [Core_ElaboratedTypeSymbol]
        ] >
    ] >
{
    let summary = "Scope, holds one region.";
    let description = [{ Scope that holds one region, each block should be terminated
                         with either branch, scope return or their conditional variants. }];

    let regions = (region AnyRegion:$body);

    let extraClassDeclaration = [{
        mlir::Block *start_block()
        {
            auto size = std::distance(getBody().begin(), getBody().end());
            if (size < 2)
                return nullptr;
            return &*std::next(getBody().begin());
        }
    }];

    let assemblyFormat = [{
        $body attr-dict
    }];
}

def LowLevel_InlineScope
    : LowLevel_Op< "inline_scope", [NoRegionArguments] >
{
    let summary = "Scope, that forwards (cond)scope return up.";
    let description = [{ Result of inlined if. }];

    let regions = (region AnyRegion:$body);
}

def LowLevel_FuncOp : Core_FuncBaseOp< LowLevel_Dialect, "func", [
    Core_FuncSymbol,
    Core_ShadowingSymbolTable< [
      [Core_VarSymbol, Core_TypeSymbol, Core_EnumConstantSymbol],
      [Core_ElaboratedTypeSymbol]
    ] >,
    IsolatedFromAbove
] > {}

#endif // VAST_DIALECT_IR_LOWLEVELOPS
