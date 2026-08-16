class ProjectInfo {
  final String name;
  final String path;
  final String kind;
  final bool hasGit;
  final String branch;
  final bool hasRemote;
  final String remoteUrl;
  final bool clean;
  final bool gitignoreOk;
  final bool pushBatOk;
  final bool readmeOk;
  final bool licenseOk;
  final bool aboutOk;
  final bool hasGitignore;
  final bool standardOk;
  final String status;
  final String version;
  final int ahead;
  final int behind;

  ProjectInfo({
    required this.name,
    required this.path,
    required this.kind,
    required this.hasGit,
    required this.branch,
    required this.hasRemote,
    required this.remoteUrl,
    required this.clean,
    required this.gitignoreOk,
    required this.pushBatOk,
    required this.readmeOk,
    required this.licenseOk,
    required this.aboutOk,
    required this.hasGitignore,
    required this.standardOk,
    required this.status,
    required this.version,
    this.ahead = 0,
    this.behind = 0,
  });

  factory ProjectInfo.fromJson(Map<String, dynamic> json) {
    return ProjectInfo(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      kind: json['kind'] ?? '',
      hasGit: json['has_git'] ?? false,
      branch: json['branch'] ?? '',
      hasRemote: json['has_remote'] ?? false,
      remoteUrl: json['remote_url'] ?? '',
      clean: json['clean'] ?? true,
      gitignoreOk: json['gitignore_ok'] ?? false,
      pushBatOk: json['push_bat_ok'] ?? false,
      readmeOk: json['readme_ok'] ?? false,
      licenseOk: json['license_ok'] ?? false,
      aboutOk: json['about_ok'] ?? false,
      hasGitignore: json['has_gitignore'] ?? false,
      standardOk: json['standard_ok'] ?? false,
      status: json['status'] ?? '',
      version: json['version'] ?? '',
      ahead: json['ahead'] ?? 0,
      behind: json['behind'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'kind': kind,
      'has_git': hasGit,
      'branch': branch,
      'has_remote': hasRemote,
      'remote_url': remoteUrl,
      'clean': clean,
      'gitignore_ok': gitignoreOk,
      'push_bat_ok': pushBatOk,
      'readme_ok': readmeOk,
      'license_ok': licenseOk,
      'about_ok': aboutOk,
      'has_gitignore': hasGitignore,
      'standard_ok': standardOk,
      'status': status,
      'version': version,
      'ahead': ahead,
      'behind': behind,
    };
  }

  ProjectInfo copyWith({
    String? name,
    String? path,
    String? kind,
    bool? hasGit,
    String? branch,
    bool? hasRemote,
    String? remoteUrl,
    bool? clean,
    bool? gitignoreOk,
    bool? pushBatOk,
    bool? readmeOk,
    bool? licenseOk,
    bool? aboutOk,
    bool? hasGitignore,
    bool? standardOk,
    String? status,
    String? version,
    int? ahead,
    int? behind,
  }) {
    return ProjectInfo(
      name: name ?? this.name,
      path: path ?? this.path,
      kind: kind ?? this.kind,
      hasGit: hasGit ?? this.hasGit,
      branch: branch ?? this.branch,
      hasRemote: hasRemote ?? this.hasRemote,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      clean: clean ?? this.clean,
      gitignoreOk: gitignoreOk ?? this.gitignoreOk,
      pushBatOk: pushBatOk ?? this.pushBatOk,
      readmeOk: readmeOk ?? this.readmeOk,
      licenseOk: licenseOk ?? this.licenseOk,
      aboutOk: aboutOk ?? this.aboutOk,
      hasGitignore: hasGitignore ?? this.hasGitignore,
      standardOk: standardOk ?? this.standardOk,
      status: status ?? this.status,
      version: version ?? this.version,
      ahead: ahead ?? this.ahead,
      behind: behind ?? this.behind,
    );
  }
}

class CloudProjectInfo {
  final String name;
  final String kind;
  final String url;
  final String updatedAt;
  final String localPath;
  final String syncStatus; // Not Cloned, Needs Pull, Up to date, Local Modified
  final bool isPrivate;
  final String version; // Latest GitHub Release tag, or '' if none published

  CloudProjectInfo({
    required this.name,
    required this.kind,
    required this.url,
    required this.updatedAt,
    required this.localPath,
    required this.syncStatus,
    required this.isPrivate,
    this.version = '',
  });

  factory CloudProjectInfo.fromJson(Map<String, dynamic> json) {
    return CloudProjectInfo(
      name: json['name'] ?? '',
      kind: json['kind'] ?? '',
      url: json['url'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      localPath: json['local_path'] ?? '',
      syncStatus: json['sync_status'] ?? 'Not Cloned',
      isPrivate: json['is_private'] ?? true,
      version: json['version'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'kind': kind,
      'url': url,
      'updated_at': updatedAt,
      'local_path': localPath,
      'sync_status': syncStatus,
      'is_private': isPrivate,
      'version': version,
    };
  }

  CloudProjectInfo copyWith({
    String? name,
    String? kind,
    String? url,
    String? updatedAt,
    String? localPath,
    String? syncStatus,
    bool? isPrivate,
    String? version,
  }) {
    return CloudProjectInfo(
      name: name ?? this.name,
      kind: kind ?? this.kind,
      url: url ?? this.url,
      updatedAt: updatedAt ?? this.updatedAt,
      localPath: localPath ?? this.localPath,
      syncStatus: syncStatus ?? this.syncStatus,
      isPrivate: isPrivate ?? this.isPrivate,
      version: version ?? this.version,
    );
  }
}
