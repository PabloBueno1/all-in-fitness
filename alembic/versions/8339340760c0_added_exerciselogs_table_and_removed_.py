"""Added ExerciseLogs table and removed reps from Exercises

Revision ID: 8339340760c0
Revises: 26b28523e5ba
Create Date: 2025-02-05 04:56:47.291966

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '8339340760c0'
down_revision: Union[str, None] = '26b28523e5ba'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    # Drop 'reps' column from exercises
    op.drop_column("exercises", "reps")

    # Create 'exercise_logs' table
    op.create_table(
        "exercise_logs",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column("exercise_id", sa.Integer(), sa.ForeignKey("exercises.id"), nullable=False),
        sa.Column("set_number", sa.Integer(), nullable=False),
        sa.Column("weight", sa.Integer(), nullable=False),
        sa.Column("reps", sa.Integer(), nullable=False),
    )


def downgrade():
    # Re-add 'reps' column to exercises in case of rollback
    op.add_column("exercises", sa.Column("reps", sa.Integer(), nullable=True))

    # Drop 'exercise_logs' if rolling back
    op.drop_table("exercise_logs")