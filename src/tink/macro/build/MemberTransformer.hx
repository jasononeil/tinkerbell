package tink.macro.build;

private typedef Enums = Type;

import haxe.macro.Context;
import haxe.macro.Type;

using tink.macro.tools.MacroTools;

/**
 * ...
 * @author back2dos
 */

typedef ClassBuildContext = {
	cls:ClassType,
	members:Array<Member>,
	getCtor:Void->Constructor,
	has:String->Bool,
	add:Member->Member
}
class MemberTransformer {
	
	var members:Hash<Member>;
	var constructor:Null<Constructor>;
	var localClass:ClassType;
	public function new() { 
		members = new Hash();
		localClass = Context.getLocalClass().get();
	}
	function getConstructor() {
		if (constructor == null) 
			if (localClass.superClass != null && localClass.superClass.t.get().constructor != null) 
				localClass.pos.error('please specify a constructor with a call to the super constructor');
			else
				constructor = new Constructor(null);
		return constructor;
	}
	function prune(a:Array<Member>) {
		var ret = [];
		for (m in a) 
			if (!m.excluded)
				ret.push(m);
		return ret;
	}
	public function build(plugins:Iterable<ClassBuildContext->Void>) {
		var fields = [];
		for (field in Context.getBuildFields()) 
			addMember(fields, Member.ofHaxe(field));
			
		var context = {
			cls: localClass,
			members: fields,
			getCtor: getConstructor,
			has: hasMember,
			add: null
		}
		
		for (plugin in plugins) {
			context.add = callback(addMember, context.members);
			
			plugin(context);	
			
			context.members = prune(context.members);
		}
			
		var ret = (constructor == null) ? [] : [constructor.toHaxe()];
		for (member in context.members)
			ret.push(member.toHaxe());
			
		return ret;
	}
	function hasMember(name:String) {
		return 
			if (name == 'new')
				constructor != null;
			else
				members.exists(name) && !members.get(name).excluded;
	}
	function addMember(to:Array<Member>, m:Member) {
		if (hasMember(m.name)) 
			m.pos.error('duplicate member declaration ' + m.name);
			
		if (m.name == 'new') 
			this.constructor = new Constructor(Enums.enumParameters(m.kind)[0], m.isPublic);
		else {
			members.set(m.name, m);
			to.push(m);				
		}
		return m;
	}		
}