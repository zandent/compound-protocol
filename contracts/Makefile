remappings=ds-test/=lib/ds-test/src/ ds-token/=lib/ds-token/src/ ds-note/=lib/ds-value/lib/ds-thing/lib/ds-note/src/ ds-value/=lib/ds-value/src/ erc20/=lib/ds-token/lib/erc20/src/ ds-math/=lib/ds-value/lib/ds-thing/lib/ds-math/src/ ds-stop/=lib/ds-token/lib/ds-stop/src/ ds-thing/=lib/ds-value/lib/ds-thing/src/ ds-auth/=lib/ds-value/lib/ds-thing/lib/ds-auth/src/
opts=--abi --bin
files=$$(find . -type f -name '*.sol')

ls:
	echo ${files}

clean:
	rm -rf out/

build: clean
	mkdir -p out/
	solc --overwrite -o out ${opts} /=/ Timelock.sol Sig_Timelock_parsed.sol
