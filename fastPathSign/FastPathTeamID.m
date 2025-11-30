#import <Foundation/Foundation.h>
#import "FastPathTeamID.h"

#include "MachO.h"
#include "CSBlob.h"
#include "CodeDirectory.h"

NSString *fastpath_get_team_identifier_for_path(NSString *path)
{
    if (path.length == 0) return nil;

    MachO *macho = macho_init_for_writing(path.fileSystemRepresentation);
    if (!macho) {
        NSLog(@"[FastPathTeamID] macho_init_for_writing failed for %@", path);
        return nil;
    }

    CS_SuperBlob *superblob = macho_read_code_signature(macho);
    if (!superblob) {
        NSLog(@"[FastPathTeamID] no code signature found for %@", path);
        macho_free(macho);
        return nil;
    }

    CS_DecodedSuperBlob *decodedSuperblob = csd_superblob_decode(superblob);
    free(superblob);
    if (!decodedSuperblob) {
        NSLog(@"[FastPathTeamID] csd_superblob_decode failed for %@", path);
        macho_free(macho);
        return nil;
    }

    CS_DecodedBlob *codeDirBlob = csd_superblob_find_blob(decodedSuperblob, CSSLOT_ALTERNATE_CODEDIRECTORIES, NULL);
    if (!codeDirBlob) {
        codeDirBlob = csd_superblob_find_blob(decodedSuperblob, CSSLOT_CODEDIRECTORY, NULL);
    }

    if (!codeDirBlob) {
        NSLog(@"[FastPathTeamID] no CodeDirectory blob found for %@", path);
        csd_superblob_free(decodedSuperblob);
        macho_free(macho);
        return nil;
    }

    char *teamId = csd_code_directory_copy_team_id(codeDirBlob, NULL);
    if (!teamId) {
        NSLog(@"[FastPathTeamID] CodeDirectory has no team ID for %@", path);
        csd_superblob_free(decodedSuperblob);
        macho_free(macho);
        return nil;
    }

    NSString *result = [NSString stringWithUTF8String:teamId];
    free(teamId);

    csd_superblob_free(decodedSuperblob);
    macho_free(macho);

    return result.length > 0 ? result : nil;
}

