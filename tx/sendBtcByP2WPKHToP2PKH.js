const bitcoin = require('bitcoinjs-lib')
// Elliptic curve
const ecc = require('tiny-secp256k1')
const {ECPairFactory} = require('ecpair')
const ECPair = ECPairFactory(ecc)
const REGTEST = bitcoin.networks.regtest

const validator = ( pubkey, msghash, signature ) => ECPair.fromPublicKey(pubkey).verify(msghash, signature);

// Private key
const keyPair = ECPair.fromWIF(
    'cPq8wmq1UaKg3bZ8PccfHULDXZkegWX43cCfo5aRks6V5CaueFyR', REGTEST
);

// p2pkh address
// bitcoin.opcodes.OP_DUP
const { address } = bitcoin.payments.p2wpkh({ pubkey: keyPair.publicKey, network: REGTEST });

console.log(address);


let psbt = new bitcoin.Psbt({ network: REGTEST });


const GOAT = '47545430';

 function buildDataEmbedScript(magicBytes, evmAddress) {
    // Parameter validation
    if (!Buffer.isBuffer(magicBytes) || magicBytes.length !== 4) {
        throw new Error("magicBytes must be a Buffer of length 4");
    }
    if (!Buffer.isBuffer(evmAddress) || evmAddress.length !== 20) {
        throw new Error("evmAddress must be a Buffer of length 20");
    }

    // Serialize data
    const serializedStakingData = Buffer.concat([
        magicBytes, // 4 bytes, endianess not applicable to byte array
        evmAddress // 20 bytes, endianess not applicable to byte array
    ]);

    return bitcoin.script.compile([bitcoin.opcodes.OP_RETURN, serializedStakingData]);
}

function buildOpenReturn(ethAddress) {
    const dataEmbedScript = buildDataEmbedScript(
        Buffer.from(GOAT, "hex"),
        ethAddress.startsWith("0x") ? Buffer.from(ethAddress.slice(2), "hex") : Buffer.from(ethAddress, "hex")
    );
    return {dataEmbedScript};
}

const psbtOutputs = [
    {
        address: 'bcrt1qjav7664wdt0y8tnx9z558guewnxjr3wllz2s9u', // Receiving address
        value: 100000000 - 1000 // Receiving amount
    },
    {
        script: buildOpenReturn('0x70997970C51812dc3A010C7d01b50e0d17dc79C8').dataEmbedScript,
        value: 0
    }
];

const selectedUTXOs = [{
    txid: '98db46419fd24617ebb4b8151dafbb01f6d8ec573083722034707930c51ce41a', // Input txid
    vout: 1, // Input vout
    scriptPubKey: '001458dc254a66e5dd3f718b6f7b42aabb5841b569f9', // Input scriptPubKey
    value: 100000000, // Input value
}];

selectedUTXOs.forEach((input) => {
    psbt.addInput({
        hash: input.txid,
        index: input.vout,
        witnessUtxo: {
            script: Buffer.from(input.scriptPubKey, "hex"),
            value: input.value
        },
        sequence: 0xfffffffd // Enable locktime by setting the sequence value to (RBF-able)
    });
});

// Add outputs to the recipient
psbt.addOutputs(psbtOutputs);

psbt.signAllInputs(keyPair);
psbt.finalizeAllInputs();
const tx = psbt.extractTransaction();
console.log('txid: ', tx.getId());
console.log('tx: ', tx.toHex());

psbt.signInput(0, keyPair);
psbt.validateSignaturesOfInput(0, validator);
psbt.finalizeAllInputs();

// Generate transaction
const rawTransaction = psbt.extractTransaction().toHex()
console.log(rawTransaction)

const Client = require('bitcoin-core');
const client = new Client({network: 'regtest', port: 8332, username: 'test', password: 'test'});
client.sendRawTransaction(rawTransaction).then(res => console.log(res))
