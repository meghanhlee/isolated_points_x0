o/////////////////////////////////////////////////
// All of our code was run on a machine with the
// following specifications.
// CPU: Apple M1 Pro
// Memory: 16 GB
// OS: macOS Sonoma Version 14.2.1
// Magma Version: V2.28-3
/////////////////////////////////////////////////


intrinsic TransposeMatrixGroup(G::GrpMat) -> GrpMat
	{ Given a matrix group G, return the
		matrix group generated by the transpose
		of each generator. }

	Gt := sub<GL(2,BaseRing(G)) | [Transpose(g):g in Generators(G)]>;

	return Gt;
end intrinsic;


intrinsic NonSurjectivePrimes(G::GrpMat) -> SeqEnum[RngIntElt]
	{ Given G the mod N reduction of the
		adelic Galois image of a non-CM elliptic
		curve where N is the level, return the
		non-surjective primes. }

	m := Modulus(BaseRing(G));

	return [p:p in PrimeFactors(m)|#ChangeRing(G,GF(p)) ne #GL(2,GF(p))];
end intrinsic;


intrinsic ReducedLevel(G::GrpMat) -> RngIntElt
	{ Given G the mod N reduction of the
		adelic Galois image of a non-CM elliptic
		curve where N is the level, return the
		level of the m-adic Galois representation
		such that m is the product of 2, 3, and
		any larger primes which are non-surjective. }

	m := Modulus(BaseRing(G));
	NS := Set(NonSurjectivePrimes(G));
	sE := {2,3} join NS;
	m0 := &*[p^Valuation(m,p):p in sE];

	G := ChangeRing(G,Integers(m0));
	for p in PrimeFactors(m0) do
		while Valuation(m0,p) gt 1 and #G/#ChangeRing(G,Integers(m0 div p)) eq p^4 do
			m0 := m0 div p;
			G := ChangeRing(G,Integers(m0));
		end while;

		if not p in NS and Valuation(m0,p) eq 1 then
			if m0 eq p then
				return 1;
			elif #G/#ChangeRing(G,Integers(m0 div p)) eq #GL(2,GF(p)) then
				m0 := m0 div p;
			end if;
		end if;
    	end for;

	return m0;
end intrinsic;


intrinsic CyclicSubspaces(m::RngIntElt) -> SetEnum[ModTupRng]
	{ Given a positive integer m,
		return the set of all cyclic
		modules with cardinality m. }
	M:=RSpace(Integers(m),2);

	return {sub<M|[i,j]>:i in Divisors(m),j in [0..m-1]|GCD(i,j) eq 1};
end intrinsic;


intrinsic GroupIsogenyDegree(H::GrpMat) -> SeqEnum[RngIntElt]
	{ Given mod m image H, return degrees of all
		closed points on X_0(m).
		This function is not called in main algorithm. }
	m:=#BaseRing(H);
	H:=sub<GL(2,Integers(m))|[Transpose(h):h in Generators(H)]>;

	return [#Orbit(H,v): v in CyclicSubspaces(m)];
end intrinsic;


intrinsic CoveringDegree(m::RngIntElt,n::RngIntElt) -> RngIntElt
	{ Given two positive integers m, n, where
		n is a divisor of m, return the degree
		of the natural map from X_0(m) to X_0(n). }

	assert(m mod n eq 0);

	if n eq 2 then
		return (1/3)*m*&*[Rationals()|(1 + 1/p):p in PrimeFactors(m)];
		end if;
	if m eq 2 then // n divides m so n = 1 or 2
		if n eq 1 then
			return 3;
		else
			return 1;
			end if;
	end if;

	a := m div n;
	b := (n le 2 and m gt 2) select 1/2 else 1;
	
	return a*&*[Rationals()|(1 + 1/p):p in PrimeFactors(m)|n mod p ne 0];
end intrinsic;


intrinsic PrimitiveDegreesOfPoints(primitivepts::SeqEnum[Any], m::RngIntElt, G::GrpMat) -> SeqEnum[Tup]
	{ Given a list to which we add primitive points, a divisor m of the
		reduced level of E, and a mod m image G, return a set of tuples
		<a1, d1>,  ..., <an, dn>, such that each
		<ai, di> pair represents a degree di primitive point
		on X_0(ai), for some divisor di of the reduced level m. }

	if m eq 1 then
	// <1, 1> is always a primitive deg 1 point on X_0(1).
		Append(~primitivepts, <1, 1>);
		return primitivepts;
	end if;

	GensG := Generators(G);
	R := RSpace(Integers(m),2);
	Gmodm := ChangeRing(G, Integers(m));
	Gt := TransposeMatrixGroup(Gmodm);

	H := sub<GL(2,Integers(m))|Gt,-Gt!1>;
	C:=SetToIndexedSet(CyclicSubspaces(m));
	
	// for-loop through each cyclic subspace of order m.
	for v in C do
		degx := #Orbit(H,v);
		
		i := 1;

		while i le #Divisors(m) do
			// 1 is the first entry in the list of divisors so this while-loop
			// always checks the degree condition on X_0(1) first.
			if i eq 1 then
				ai := Divisors(m)[i]; // a1 = 1
				degf1 := CoveringDegree(m, 1);

				// note degx1 = 1 since we have rational j-invariant.
				if degx eq degf1 then
						Append(~primitivepts, <ai, 1>);
						// degree condition met so continue to next v in C.
						i := #Divisors(m)+1;

				elif degx ne degf1 then
					// degree condition not met, continue to next divisor.
					i +:= 1;
				end if;
			end if;

			// i = #Divisors(m)+1 is used to break the while-loop
			// and continue to the next v in C.
			if i eq #Divisors(m)+1 then
				break;
			end if;

        		ai := Divisors(m)[i];
			degfi := CoveringDegree(m, ai);
			
			// K is the module Z/aiZ^{(2)},
			// consisting of all 2-tuples over Z/aiZ.
			K := RSpace(Integers(ai),2);
			HmodAi := ChangeRing(H, Integers(ai));
			
			// to compute the degree of the image xi on X_0(ai), we now need the
			// subspace of K generated by the generator of v (mod ai).
			L := sub<K|K!v.1>;
			
			degxi := #Orbit(HmodAi,L);

			// if the degree di of the image of the point on X_0(ai) is as large as possible:
			if degx eq degfi * degxi then
				Append(~primitivepts, <ai,degxi>);
				i := #Divisors(m)+1;

			elif i eq #Divisors(m) then
				Append(~primitivepts, <Divisors(m)[i],degx>);
				i := #Divisors(m)+1;
			elif i ne #Divisors(m) then
				// check the next largest divisor of m
				i +:= 1;

			end if;
		end while;
	end for;
	return primitivepts;
end intrinsic;

intrinsic FilterByRiemannRoch(primitivepts::SeqEnum[Tup]) -> SeqEnum[Tup]
	{ Given multiset of elements of the form
		<a1, d1>,  ... , <an, dn>,
		return those such that di is
		greater than genus(X_0(ai))
		for some i. }

	A := AssociativeArray();

	function CachedGenus(m,A)
		if m notin Keys(A) then
			A[m] := Genus(Gamma0(m));
		end if;
		return A[m], A;
	end function;
	
	function RiemannRochFilter(points,A)
		list := {*Parent({<1,1>})|  *};
		nonisolated := [];
		possibleisolated := [];
		for x in primitivepts do
			a, deg := Explode(x);
			genusGamma0, A := CachedGenus(a,A);
			
			// append those P1-parametrized by
			// Riemann-Roch Theorem
			if deg ge genusGamma0 + 1 then
				Append(~nonisolated,x);
			else
				Append(~possibleisolated,x);
			end if;
		end for;
		return possibleisolated;
	end function;

	returnlist := RiemannRochFilter(primitivepts,A);

	return returnlist;
end intrinsic;

intrinsic PrintCount(points::SeqEnum[Tup]) -> MonStgElt
	{ Helper function to read multiplicities
		to read output from FilterByRiemannRoch and
		PrimitiveDegreesOfPoints.
		This function is not called in
		our main algorithm. }

    	multiplicity := AssociativeArray();
	str := "";

	if #points eq 0 then
		str cat:=("All points are non-isolated.");
		return str;
	end if;
		
	for tuple in points do
		if IsDefined(multiplicity, tuple) then
			multiplicity[tuple] +:= 1;
		else
			multiplicity[tuple] := 1;
		end if;
	end for;

	// For reading the results
	counts := [];
	for key in Keys(multiplicity) do
		Append(~counts, <key, multiplicity[key]>);
	end for;

    	for entry in counts do
        	key := entry[1];
        	count := entry[2];
        	str cat:= Sprintf("<%o, %o>^%o\n", key[1], key[2], count);
    	end for;
    	return str;
end intrinsic;

intrinsic NotIsolated(j::FldRatElt, path::Assoc : ainvs :=[]) -> List
	{ Main function to check if a rational
		j-invariant is isolated. }

	CMjinv := [ -12288000, 54000, 0, 287496, 1728, 16581375, -3375, 8000, -32768, -884736, -884736000, 			-147197952000, -262537412640768000];
	require j notin CMjinv : "j is a CM j-invariant. All CM j-invariants are isolated.";

	if ainvs eq [] then
		E := EllipticCurveFromjInvariant(j);
	else
		require #ainvs eq 5 : "ainvs should be a list of Weierstrass coefficients for the elliptic curve";
		E := EllipticCurve(ainvs);
		require Rationals()!jInvariant(E) eq j : "The j-invariant of the elliptic curve specified by the 			Weierstrass coefficients should match the given j-invariant";
	end if;	

	function FilterOutByGenus0(possibleisolated, G)
		// Given a list of tuples <ai, di>, return those
		// for which the image of G mod ai does not
		// have genus equal to 0.
		S := {* *};

		for point in possibleisolated do
			ai, di := Explode(point);
			Gmodai := ChangeRing(G,Integers(ai));
			if GL2Genus(Gmodai) ne 0 then
				Include(~S, point);
			end if;
		end for;

		return S;
	end function;

	G,_,_ := FindOpenImage(path, E);
	m0 := ReducedLevel(G);

	if m0 eq 1 then
		return [* j, []*];
	end if;

	G0 := ChangeRing(G,Integers(m0));
	m := Modulus(BaseRing(TransposeMatrixGroup(G0)));
	possibleisolated := {};
	
	for a in Divisors(m) do
		primitivepts := [];
		for pair in PrimitiveDegreesOfPoints(primitivepts, a, G0) do
			Include(~possibleisolated, pair);
		end for;
	end for;

	possibleisolated := SetToIndexedSet(possibleisolated);
	possibleisolated := IndexedSetToSequence(possibleisolated);
	possibleisolatedfilter1 := FilterByRiemannRoch(possibleisolated);

	if #possibleisolatedfilter1 gt 0 then
		possibleisolatedfilter2 := FilterOutByGenus0(possibleisolatedfilter1,G0);
		return [* j, possibleisolatedfilter2*];
	else
		return [* j, possibleisolatedfilter1*];
	end if;
end intrinsic;