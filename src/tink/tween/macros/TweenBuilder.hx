package tink.tween.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import tink.macro.tools.AST;
import haxe.macro.Type;
import tink.macro.tools.TypeTools;

using tink.macro.tools.MacroTools;
using tink.core.types.Outcome;
using StringTools;
/**
 * ...
 * @author back2dos
 */

class TweenBuilder {
	static var ITERABLE = 'Iterable'.asTypePath([TPType('Dynamic'.asTypePath())]);
	static function handler(body:Expr, targetType:Type) {
		return 
			body.func(
				['tween'.toArg('tink.tween.Tween'.asTypePath([TPType(targetType.toComplex())]))]
				, false
			).toExpr(body.pos);
	}
	static function atomStatic(name:String, op) {
		return
			AST.build(
				function (tmpTarget) {
					if (false) tmpTarget.eval__name = .0;
					//the above is needed to make the type inferrer understand, that the field provides write access (otherwise inference will cause an error within the scope of this function), but the optimizer will throw this out for us
					var tmpStart:Float = tmpTarget.eval__name;
					var tmpDelta = $(op.e2) - tmpStart;
					return
						function (amplitude:Float) {
							if (amplitude < 1e30)
								tmpTarget.eval__name = tmpStart + tmpDelta * amplitude;
							else
								tmpTarget = null;
							return null;
						}
				},			
				op.pos
			);
	}
	static function atomDynamic(name:String, op) {
		return
			AST.build(
				function (tmpTarget) {
					var tmpStart:Float = tink.reflect.Property.get(tmpTarget, "eval__name");
					var tmpDelta = $(op.e2) - tmpStart;
					return
						function (amplitude:Float) {
							if (amplitude < 1e30)
								tink.reflect.Property.set(tmpTarget, "eval__name", tmpStart + tmpDelta * amplitude);
							else
								tmpTarget = null;
							return null;
						}
				},			
				op.pos
			);			
	}
	static public function buildTween(target:Expr, group:Expr, params:Array<Expr>) {
		var targetType = target.typeof().data();
		var isDynamic = 
			switch (targetType) {
				case TDynamic(_): 
					#if debug 
						Context.warning('Type appears to be Dynamic. No type checking can be performed, no plugins will work. This warning is only issued with -debug', target.pos);
					#end
					true;
				default: false;
			}
		
		var targetCT = targetType.toComplex(),
			tmp = String.tempName();
		
		var ret = [tmp.define(AST.build(new tink.tween.Tween.TweenParams<Eval__targetCT>()))];//just to be sure
		
		for (e in params) {
			var op = OpAssign.get(e).data();
			var name = op.e1.getIdent().data();
			ret.push(
				if (name.charAt(0) == '$') {
					var e = 
						if (name.substr(0,3) == '$on') 
							switch (op.e2.typeof()) {
								case Success(t):
									switch (t.reduce()) {
										case TFun(_, _): op.e2;
										default: handler(op.e2, targetType);
									}
								default:
									handler(op.e2, targetType);
							}
						else op.e2;
					tmp.resolve(op.pos).field(name.substr(1), op.e1.pos).assign(e, op.pos);
				}
				else {
					var atom = 
						switch (target.field(name).typeof()) {
							case Success(_):
								if (isDynamic) 
									atomDynamic(name, op);
								else 
									atomStatic(name, op);
							case Failure(f):
								var tp = PluginMap.getPluginFor(target, name);
								if (tp == null) 
									f.throwSelf();
								else {
									var tmp = String.tempName();
									var inst = ENew(tp, [tmp.resolve(), op.e2]).at(op.e1.pos).field('update', op.pos);
									inst.func([tmp.toArg()], 'Dynamic'.asTypePath()).toExpr(op.pos);
								}
						}
					AST.build(eval__tmp.addAtom("eval__name", $atom), op.pos);	
				}
			);
		}
		ret.push(AST.build(eval__tmp.start($group, $target)));
		return ret.toBlock();
	}
}