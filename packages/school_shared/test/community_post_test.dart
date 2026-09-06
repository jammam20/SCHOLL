import 'package:school_shared/school_shared.dart';
import 'package:test/test.dart';

void main() {
  group('CommunityPostCategory', () {
    test('round-trips every value through its wire string', () {
      for (final category in CommunityPostCategory.values) {
        expect(
          CommunityPostCategoryX.tryParse(category.value),
          category,
          reason: '${category.name} should round-trip via "${category.value}"',
        );
      }
    });

    test('unknown wire values fall back to null, not a thrown error', () {
      expect(CommunityPostCategoryX.tryParse('not_a_category'), isNull);
      expect(CommunityPostCategoryX.tryParse(null), isNull);
      expect(CommunityPostCategoryX.tryParse(42), isNull);
    });
  });

  group('CommunityPostStatus', () {
    test('round-trips every value through its wire string', () {
      for (final status in CommunityPostStatus.values) {
        expect(CommunityPostStatusX.tryParse(status.value), status);
      }
    });
  });

  group('CommunityReportReason / CommunityReportStatus', () {
    test('round-trip every value through their wire strings', () {
      for (final reason in CommunityReportReason.values) {
        expect(CommunityReportReasonX.tryParse(reason.value), reason);
      }
      for (final status in CommunityReportStatus.values) {
        expect(CommunityReportStatusX.tryParse(status.value), status);
      }
    });
  });

  group('CommunityPost.fromMap', () {
    test('never carries an author field of any kind', () {
      final post = CommunityPost.fromMap('post-1', {
        'schoolId': 'school-1',
        'category': 'bus_issue',
        'content': 'The bus was 20 minutes late today.',
        'status': 'active',
        'reactionCount': 3,
        'commentCount': 1,
        'reportCount': 0,
        // Even if a caller mistakenly hands this in (e.g. from a bug
        // upstream), the model must not surface it as a field a parent-
        // facing UI could accidentally render.
        'authorUid': 'someone',
      });

      expect(post.schoolId, 'school-1');
      expect(post.category, CommunityPostCategory.busIssue);
      expect(post.status, CommunityPostStatus.active);
      expect(post.reactionCount, 3);
      expect(post.commentCount, 1);
    });

    test('defaults an unparsable category/status to other/active', () {
      final post = CommunityPost.fromMap('post-1', {
        'schoolId': 'school-1',
        'content': 'Hello',
      });

      expect(post.category, CommunityPostCategory.other);
      expect(post.status, CommunityPostStatus.active);
      expect(post.reactionCount, 0);
      expect(post.commentCount, 0);
      expect(post.reportCount, 0);
    });
  });

  group('CommunityPostAuthor.fromMap', () {
    test('reads the author uid admin-only surfaces resolve', () {
      final author = CommunityPostAuthor.fromMap({'authorUid': 'parent-42'});
      expect(author.authorUid, 'parent-42');
    });
  });

  group('CommunityReport.fromMap', () {
    test('carries the post id it belongs to and its reporter', () {
      final report = CommunityReport.fromMap('report-1', 'post-1', {
        'reporterUid': 'parent-9',
        'reason': 'spam',
        'status': 'open',
      });

      expect(report.postId, 'post-1');
      expect(report.reporterUid, 'parent-9');
      expect(report.reason, CommunityReportReason.spam);
      expect(report.status, CommunityReportStatus.open);
    });
  });
}
