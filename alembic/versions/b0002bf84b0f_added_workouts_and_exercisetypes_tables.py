"""Added Workouts and ExerciseTypes tables

Revision ID: b0002bf84b0f
Revises: ec613512c79c
Create Date: 2025-02-05 04:22:05.401570

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b0002bf84b0f'
down_revision: Union[str, None] = 'ec613512c79c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    print("Skipping: Workouts and ExerciseTypes tables already exist.")


def downgrade() -> None:
    op.drop_table('exercise_types')
    op.drop_table('workouts')

